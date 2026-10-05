require "rails_helper"

# Regression coverage for the payroll-correctness fixes: TDS projection from
# actual year-to-date pay, the component taxable flag, the tds_enabled
# setting, locked-only attendance, the date-effective PF ceiling and ESI
# contribution-period continuity.
RSpec.describe Payroll::SalaryCalculator do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }

  before { set_tenant(tenant) }

  let(:basic_comp)      { create(:salary_component, tenant: tenant, name: "Basic",                calculation_type: "percentage", sort_order: 1) }
  let(:hra_comp)        { create(:salary_component, tenant: tenant, name: "HRA",                  calculation_type: "percentage", sort_order: 2) }
  let(:special_comp)    { create(:salary_component, tenant: tenant, name: "Special Allowance",    calculation_type: "percentage", sort_order: 3) }
  let(:conveyance_taxable) { true }
  let(:conveyance_comp) do
    create(:salary_component, tenant: tenant, name: "Conveyance Allowance", calculation_type: "flat",
           sort_order: 4, taxable: conveyance_taxable)
  end

  # Basic 40%, HRA 20%, Special 30% of CTC + Conveyance ₹1,600 flat
  let(:structure) do
    s = create(:salary_structure, tenant: tenant, name: "Standard CTC")
    create(:salary_structure_component, salary_structure: s, salary_component: basic_comp,      value: 40)
    create(:salary_structure_component, salary_structure: s, salary_component: hra_comp,        value: 20)
    create(:salary_structure_component, salary_structure: s, salary_component: special_comp,    value: 30)
    create(:salary_structure_component, salary_structure: s, salary_component: conveyance_comp, value: 1600)
    s.reload
  end

  let(:tds_enabled) { true }
  let(:esi_enabled) { false }
  let(:setting) do
    create(:payroll_setting, tenant: tenant, pf_enabled: true, esi_enabled: esi_enabled,
           pt_enabled: false, tds_enabled: tds_enabled)
  end

  let(:joining_date) { Date.new(2025, 1, 1) }
  let(:last_working_date) { nil }
  let(:employee) do
    create(:employee, tenant: tenant, joining_date: joining_date, last_working_date: last_working_date,
           pf_applicable: true, pt_applicable: false)
  end

  let(:run_month) { 1 }
  let(:run_year)  { 2026 }
  let(:payroll_run) { create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: run_month, year: run_year) }

  def setup_salary(annual_ctc:)
    create(:employee_salary, tenant: tenant, employee: employee, salary_structure: structure, annual_ctc: annual_ctc)
  end

  def setup_attendance(status: :locked)
    create(:attendance_summary, status: status, tenant: tenant, employee: employee,
           month: payroll_run.month, year: payroll_run.year, total_working_days: 22, days_present: 22)
  end

  # An earlier, approved payslip in the same financial year.
  def paid_payslip(month:, year:, lines:)
    run = create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: month, year: year)
    payslip = create(:payslip, tenant: tenant, payroll_run: run, employee: employee, month: month, year: year)
    lines.each do |name, type, amount, taxable|
      create(:payslip_line_item, payslip: payslip, component_name: name, component_type: type,
             amount: amount, full_amount: nil, taxable: taxable.nil? ? true : taxable)
    end
    payslip
  end

  def calculator
    described_class.new(employee: employee, payroll_run: payroll_run, payroll_setting: setting)
  end

  describe "TDS projection" do
    context "for an employee who joined mid-year (October 2026, ₹24L CTC)" do
      let(:joining_date) { Date.new(2026, 10, 1) }
      let(:run_month)    { 10 }
      let(:run_year)     { 2026 }

      before do
        setup_salary(annual_ctc: 2_400_000)   # gross 1,81,600 / month
        setup_attendance
      end

      it "projects six months of income, not twelve" do
        expect(Statutory::TdsCalculator).to receive(:new)
          .with(hash_including(annual_gross: 181_600 * 6)).and_call_original
        calculator.call
      end

      it "deducts no TDS when six months' income is within the 87A rebate" do
        # 10,89,600 − 75,000 standard deduction = 10,14,600 ≤ ₹12L
        expect(calculator.call.deductions).not_to have_key("TDS")
      end
    end

    context "with taxable pay and TDS already paid this financial year" do
      let(:run_month) { 10 }
      let(:run_year)  { 2026 }

      before do
        setup_salary(annual_ctc: 1_200_000)   # gross 91,600 / month
        setup_attendance
        paid_payslip(month: 9, year: 2026, lines: [
          [ "Diwali Bonus", "earning", 300_000 ],
          [ "TDS", "deduction", 10_000, false ]
        ])
      end

      it "adds year-to-date taxable pay to this month and the five months ahead" do
        expect(Statutory::TdsCalculator).to receive(:new)
          .with(hash_including(annual_gross: 300_000 + 91_600 + 91_600 * 5, ytd_tds_deducted: 10_000))
          .and_call_original
        calculator.call
      end

      it "ignores pay from the previous financial year" do
        paid_payslip(month: 3, year: 2026, lines: [ [ "Old Bonus", "earning", 500_000 ] ])
        expect(Statutory::TdsCalculator).to receive(:new)
          .with(hash_including(annual_gross: 300_000 + 91_600 * 6)).and_call_original
        calculator.call
      end
    end

    context "when a component is marked non-taxable" do
      let(:conveyance_taxable) { false }

      before do
        setup_salary(annual_ctc: 1_200_000)
        setup_attendance
      end

      it "records it on the result so the payslip line is stored non-taxable" do
        expect(calculator.call.non_taxable_components).to eq([ "Conveyance Allowance" ])
      end

      it "leaves it out of taxable income" do
        # January: this month + February + March, each 91,600 − 1,600
        expect(Statutory::TdsCalculator).to receive(:new)
          .with(hash_including(annual_gross: 90_000 * 3)).and_call_original
        calculator.call
      end
    end

    context "when the last working date is known" do
      let(:run_month)         { 10 }
      let(:run_year)          { 2026 }
      let(:last_working_date) { Date.new(2026, 11, 30) }

      before do
        setup_salary(annual_ctc: 1_200_000)
        setup_attendance
      end

      it "projects only to the exit month and spreads tax over those months" do
        expect(Statutory::TdsCalculator).to receive(:new)
          .with(hash_including(annual_gross: 91_600 * 2, remaining_months: 2)).and_call_original
        calculator.call
      end
    end

    context "80C under the old regime" do
      before do
        setup_salary(annual_ctc: 1_200_000)   # Basic 40,000 → PF capped at 1,800 (Jan 2026)
        setup_attendance
      end

      it "passes the PF actually deducted, not 12% of Basic" do
        expect(Statutory::TdsCalculator).to receive(:new)
          .with(hash_including(annual_employee_pf: 1_800 * 3)).and_call_original
        calculator.call
      end
    end

    context "when TDS is disabled in payroll settings" do
      let(:tds_enabled) { false }

      before do
        setup_salary(annual_ctc: 6_000_000)
        setup_attendance
      end

      it "deducts no TDS" do
        expect(calculator.call.deductions).not_to have_key("TDS")
      end
    end
  end

  describe "attendance" do
    before { setup_salary(annual_ctc: 1_200_000) }

    it "refuses draft attendance" do
      setup_attendance(status: :draft)
      expect { calculator.call }.to raise_error(described_class::CalculationError, /No attendance summary/)
    end
  end

  describe "PF wage ceiling" do
    before do
      setup_salary(annual_ctc: 1_200_000)   # Basic 40,000
      setup_attendance
    end

    context "in October 2026" do
      let(:run_month) { 10 }
      let(:run_year)  { 2026 }

      it "caps PF at 12% of ₹25,000" do
        expect(calculator.call.deductions["PF"]).to eq(3_000)
      end
    end

    context "in September 2026 (ceiling changed on the 17th)" do
      let(:run_month) { 9 }
      let(:run_year)  { 2026 }

      it "caps PF at 12% of the prorated ceiling (₹19,666.67)" do
        expect(calculator.call.deductions["PF"]).to eq(2_360)
      end
    end

    context "before September 2026" do
      it "caps PF at 12% of ₹15,000" do
        expect(calculator.call.deductions["PF"]).to eq(1_800)
      end
    end
  end

  describe "ESI contribution period" do
    let(:esi_enabled) { true }
    let(:run_month)   { 9 }
    let(:run_year)    { 2026 }

    before do
      setup_salary(annual_ctc: 273_600)   # gross 22,120 / month — above ₹21,000
      setup_attendance
    end

    it "continues ESI when it was deducted earlier in the April–September period" do
      paid_payslip(month: 8, year: 2026, lines: [ [ "ESI", "deduction", 150, false ] ])
      expect(calculator.call.deductions["ESI"]).to eq((22_120 * 0.0075).ceil)
    end

    it "does not start ESI for a gross above the ceiling" do
      expect(calculator.call.deductions).not_to have_key("ESI")
    end

    it "does not carry coverage across into a new period" do
      paid_payslip(month: 8, year: 2026, lines: [ [ "ESI", "deduction", 150, false ] ])
      october = create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 10, year: 2026)
      create(:attendance_summary, :locked, tenant: tenant, employee: employee, month: 10, year: 2026,
             total_working_days: 22, days_present: 22)
      result = described_class.new(employee: employee, payroll_run: october, payroll_setting: setting).call
      expect(result.deductions).not_to have_key("ESI")
    end
  end
end
