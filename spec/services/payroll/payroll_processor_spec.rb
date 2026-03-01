require "rails_helper"

RSpec.describe Payroll::PayrollProcessor do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }

  before do
    set_tenant(tenant)
    # Stub Turbo broadcast so tests don't need ActionCable
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  # Shared salary structure setup
  let(:basic_comp)   { create(:salary_component, tenant: tenant, name: "Basic", calculation_type: "percentage", sort_order: 1) }
  let(:hra_comp)     { create(:salary_component, tenant: tenant, name: "HRA",   calculation_type: "percentage", sort_order: 2) }

  let(:structure) do
    s = create(:salary_structure, tenant: tenant, name: "Standard CTC")
    create(:salary_structure_component, salary_structure: s, salary_component: basic_comp, value: 40)
    create(:salary_structure_component, salary_structure: s, salary_component: hra_comp,   value: 20)
    s.reload
  end

  let!(:setting) do
    create(:payroll_setting, :no_pt, tenant: tenant,
           pf_enabled: true, esi_enabled: false, tds_enabled: false)
  end

  let(:payroll_run) do
    create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
  end

  def create_ready_employee(employment_status: "active")
    emp = create(:employee, tenant: tenant, employment_status: employment_status,
                 pan_number: "ABCDE1234F", pf_applicable: true, pt_applicable: false)
    create(:employee_salary, tenant: tenant, employee: emp,
           salary_structure: structure, annual_ctc: 600_000)
    create(:attendance_summary, :locked, tenant: tenant, employee: emp,
           month: payroll_run.month, year: payroll_run.year,
           total_working_days: 22, days_present: 22)
    emp
  end

  describe "#call" do
    context "with one fully eligible employee" do
      let!(:employee) { create_ready_employee }

      subject(:result) { described_class.new(payroll_run: payroll_run).call }

      it "returns a ProcessingResult" do
        expect(result).to be_a(Payroll::PayrollProcessor::ProcessingResult)
      end

      it "transitions payroll_run to processed" do
        result
        expect(payroll_run.reload.status).to eq("processed")
      end

      it "creates one payslip" do
        expect { result }.to change { payroll_run.payslips.count }.by(1)
      end

      it "creates line items for the payslip" do
        result
        expect(payroll_run.payslips.first.line_items.count).to be > 0
      end

      it "reports 1 processed, 0 skipped" do
        expect(result.processed.count).to eq(1)
        expect(result.skipped.count).to eq(0)
      end

      it "updates payroll_run totals" do
        result
        run = payroll_run.reload
        expect(run.total_gross).to be > 0
        expect(run.total_net_pay).to be > 0
        expect(run.total_net_pay).to be < run.total_gross
      end

      it "updates processed_employees count" do
        result
        expect(payroll_run.reload.processed_employees).to eq(1)
      end

      it "broadcasts progress updates" do
        result
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).at_least(:once)
      end
    end

    context "when employee has no salary assigned" do
      let!(:employee) do
        emp = create(:employee, tenant: tenant, employment_status: "active",
                     pan_number: "ABCDE1234F")
        create(:attendance_summary, :locked, tenant: tenant, employee: emp,
               month: payroll_run.month, year: payroll_run.year,
               total_working_days: 22, days_present: 22)
        emp
        # No employee_salary created intentionally
      end

      subject(:result) { described_class.new(payroll_run: payroll_run).call }

      it "skips the employee" do
        expect(result.skipped.count).to eq(1)
        expect(result.processed.count).to eq(0)
      end

      it "records the error reason" do
        expect(result.errors.first[:error]).to match(/No salary assigned/)
      end

      it "does not create a payslip" do
        result
        expect(payroll_run.payslips.count).to eq(0)
      end

      it "still transitions to processed" do
        result
        expect(payroll_run.reload.status).to eq("processed")
      end
    end

    context "when employee has no attendance summary" do
      let!(:employee) do
        emp = create(:employee, tenant: tenant, employment_status: "active",
                     pan_number: "ABCDE1234F", pf_applicable: true)
        create(:employee_salary, tenant: tenant, employee: emp,
               salary_structure: structure, annual_ctc: 600_000)
        emp
        # No attendance summary created intentionally
      end

      subject(:result) { described_class.new(payroll_run: payroll_run).call }

      it "skips the employee" do
        expect(result.skipped.count).to eq(1)
      end

      it "records the error reason" do
        expect(result.errors.first[:error]).to match(/No attendance summary/)
      end
    end

    context "with mix of eligible and ineligible employees" do
      let!(:good_emp) { create_ready_employee }
      let!(:bad_emp) do
        # Missing salary
        emp = create(:employee, tenant: tenant, employment_status: "active",
                     pan_number: "XYZDE1234F")
        create(:attendance_summary, :locked, tenant: tenant, employee: emp,
               month: payroll_run.month, year: payroll_run.year,
               total_working_days: 22, days_present: 22)
        emp
      end

      subject(:result) { described_class.new(payroll_run: payroll_run).call }

      it "processes the good employee and skips the bad one" do
        expect(result.processed.count).to eq(1)
        expect(result.skipped.count).to eq(1)
      end

      it "creates exactly one payslip" do
        result
        expect(payroll_run.payslips.count).to eq(1)
        expect(payroll_run.payslips.first.employee_id).to eq(good_emp.id)
      end
    end

    context "employee eligibility" do
      it "includes probation employees" do
        create_ready_employee(employment_status: "probation")
        result = described_class.new(payroll_run: payroll_run).call
        expect(result.processed.count).to eq(1)
      end

      it "excludes resigned employees whose last_working_date is not in the run month" do
        emp = create(:employee, tenant: tenant, employment_status: "resigned",
                     last_working_date: 3.months.ago.to_date, pan_number: "ZYXKL1234J")
        create(:employee_salary, tenant: tenant, employee: emp,
               salary_structure: structure, annual_ctc: 600_000)
        create(:attendance_summary, :locked, tenant: tenant, employee: emp,
               month: payroll_run.month, year: payroll_run.year,
               total_working_days: 22, days_present: 22)

        result = described_class.new(payroll_run: payroll_run).call
        expect(result.processed).not_to include(emp.id)
      end
    end
  end
end
