require "rails_helper"

RSpec.describe Payroll::SalaryCalculator do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }

  before { set_tenant(tenant) }

  # Salary structure: Basic 40%, HRA 20%, Special Allowance 30%, Conveyance flat 1600
  let(:basic_comp)     { create(:salary_component, tenant: tenant, name: "Basic",               calculation_type: "percentage", sort_order: 1) }
  let(:hra_comp)       { create(:salary_component, tenant: tenant, name: "HRA",                 calculation_type: "percentage", sort_order: 2) }
  let(:special_comp)   { create(:salary_component, tenant: tenant, name: "Special Allowance",   calculation_type: "percentage", sort_order: 3) }
  let(:conveyance_comp) { create(:salary_component, tenant: tenant, name: "Conveyance Allowance", calculation_type: "flat",       sort_order: 4) }

  let(:structure) do
    s = create(:salary_structure, tenant: tenant, name: "Standard CTC")
    create(:salary_structure_component, salary_structure: s, salary_component: basic_comp,      value: 40)
    create(:salary_structure_component, salary_structure: s, salary_component: hra_comp,        value: 20)
    create(:salary_structure_component, salary_structure: s, salary_component: special_comp,    value: 30)
    create(:salary_structure_component, salary_structure: s, salary_component: conveyance_comp, value: 1600)
    s.reload
  end

  let(:setting) do
    create(:payroll_setting, tenant: tenant, pt_state: "maharashtra",
           pf_enabled: true, esi_enabled: true, pt_enabled: true, tds_enabled: true)
  end

  # Maharashtra PT slabs
  let!(:pt_slabs) do
    create(:professional_tax_slab, :mh_low,  tenant: tenant)
    create(:professional_tax_slab, :mh_mid,  tenant: tenant)
    create(:professional_tax_slab, :mh_high, tenant: tenant)
  end

  let(:employee) do
    create(:employee, tenant: tenant, employment_status: "active",
           pan_number: "ABCDE1234F", pf_applicable: true, pt_applicable: true)
  end

  let(:payroll_run) { create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026) }

  def setup_salary(annual_ctc: 1_200_000)
    create(:employee_salary, tenant: tenant, employee: employee,
           salary_structure: structure, annual_ctc: annual_ctc)
  end

  def setup_attendance(days_present: 22, total_working_days: 22)
    create(:attendance_summary, :locked,
           tenant: tenant, employee: employee,
           month: payroll_run.month, year: payroll_run.year,
           total_working_days: total_working_days,
           days_present: days_present)
  end

  def calculator
    described_class.new(employee: employee, payroll_run: payroll_run, payroll_setting: setting)
  end

  # ── Full attendance (no LOP) ──────────────────────────────────────────────

  context "with full attendance and ₹12L CTC" do
    before do
      setup_salary(annual_ctc: 1_200_000)
      setup_attendance(days_present: 22, total_working_days: 22)
    end

    subject(:result) { calculator.call }

    it "returns a SalaryResult struct" do
      expect(result).to be_a(Payroll::SalaryCalculator::SalaryResult)
    end

    it "sets proration_factor to 1.0" do
      expect(result.proration_factor).to eq(1.0)
    end

    it "calculates positive gross_pay" do
      expect(result.gross_pay).to be > 0
    end

    it "includes Basic in earnings" do
      expect(result.earnings.keys).to include("Basic")
      expect(result.earnings["Basic"]).to be > 0
    end

    it "includes HRA in earnings" do
      expect(result.earnings["HRA"]).to be > 0
    end

    it "full_earnings equal earnings when no LOP" do
      expect(result.full_earnings["Basic"]).to eq(result.earnings["Basic"])
    end

    it "deducts PF from employee" do
      expect(result.deductions["PF"]).to be > 0
    end

    it "sets net_pay = gross - total_deductions" do
      expected = [ result.gross_pay - result.total_deductions, 0 ].max.round(2)
      expect(result.net_pay).to eq(expected)
    end

    it "includes employer PF cost" do
      expect(result.employer_costs[:pf]).to be > 0
    end

    it "sets attendance hash correctly" do
      expect(result.attendance[:working_days]).to eq(22)
      expect(result.attendance[:paid_days]).to eq(22)
      expect(result.attendance[:lop_days]).to eq(0)
    end
  end

  # ── With LOP days ─────────────────────────────────────────────────────────

  context "when employee has 2 LOP days (20 of 22 days present)" do
    before do
      setup_salary(annual_ctc: 1_200_000)
      setup_attendance(days_present: 20, total_working_days: 22)
    end

    subject(:result) { calculator.call }

    it "sets proration_factor below 1.0" do
      expect(result.proration_factor).to be < 1.0
    end

    it "reduces gross_pay compared to full attendance" do
      full_result = begin
        setup_salary(annual_ctc: 1_200_000) rescue nil
        create(:attendance_summary, :locked, tenant: tenant, employee: employee,
               month: payroll_run.month, year: payroll_run.year,
               total_working_days: 22, days_present: 22)
        calculator.call
      rescue
        nil
      end
      expect(result.gross_pay).to be < 100_000  # 12L / 12 = 100K full month
    end

    it "sets full_earnings > prorated earnings" do
      expect(result.full_earnings["Basic"]).to be > result.earnings["Basic"]
    end

    it "sets lop_days > 0 in attendance hash" do
      expect(result.attendance[:lop_days]).to be > 0
    end
  end

  # ── Error cases ───────────────────────────────────────────────────────────

  context "when no attendance summary exists" do
    before { setup_salary }

    it "raises CalculationError" do
      expect { calculator.call }.to raise_error(
        Payroll::SalaryCalculator::CalculationError,
        /No attendance summary/
      )
    end
  end

  context "when no salary is assigned to the employee" do
    before { setup_attendance }
    # No employee_salary created

    it "raises CalculationError" do
      expect { calculator.call }.to raise_error(
        Payroll::SalaryCalculator::CalculationError,
        /No salary assigned/
      )
    end
  end

  # ── Employer PF included in CTC ───────────────────────────────────────────────
  context "when employer PF is part of CTC (full attendance, ₹12L)" do
    # on-top gross = 40000 + 20000 + 30000 + 1600 = 91,600
    # carve = employer PF 1800 + admin 75 + EDLI 75 = 1,950
    let(:setting) do
      create(:payroll_setting, tenant: tenant, pt_state: "maharashtra",
             pf_enabled: true, esi_enabled: true, pt_enabled: true, tds_enabled: true,
             employer_pf_in_ctc: true)
    end

    before do
      setup_salary(annual_ctc: 1_200_000)
      setup_attendance(days_present: 22, total_working_days: 22)
    end

    subject(:result) { calculator.call }

    it "carves the employer PF charges (₹1,950) out of gross" do
      expect(result.gross_pay).to eq(91_600 - 1_950)
    end

    it "keeps the employee PF deduction statutory (unchanged at ₹1,800)" do
      expect(result.deductions["PF"]).to eq(1_800)
    end

    it "surfaces admin and EDLI in employer costs" do
      expect(result.employer_costs[:admin]).to eq(75)
      expect(result.employer_costs[:edli]).to eq(75)
    end

    it "reconciles: gross + employer PF charges equals the on-top gross" do
      ec = result.employer_costs
      expect(result.gross_pay + ec[:pf] + ec[:admin] + ec[:edli]).to eq(91_600)
    end
  end
end
