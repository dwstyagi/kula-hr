require "rails_helper"

RSpec.describe Payroll::FullAndFinalPreview do
  let(:tenant) { create(:tenant) }
  let(:employee) { create(:employee, tenant: tenant, joining_date: Date.new(2025, 1, 1)) }
  let(:last_working_date) { Date.new(2026, 8, 15) }

  before do
    set_tenant(tenant)
    create(:payroll_setting, tenant: tenant, pf_enabled: false, esi_enabled: false, pt_enabled: false)
    structure = create(:salary_structure, tenant: tenant)
    basic = create(:salary_component, tenant: tenant, name: "Basic", calculation_type: "percentage")
    create(:salary_structure_component, salary_structure: structure, salary_component: basic, value: 40)
    create(
      :employee_salary,
      tenant: tenant,
      employee: employee,
      salary_structure: structure,
      annual_ctc: 600_000,
      effective_from: Date.new(2025, 1, 1),
      effective_to: last_working_date
    )
    leave_type = create(:leave_type, :earned, tenant: tenant)
    create(
      :leave_balance,
      tenant: tenant,
      employee: employee,
      leave_type: leave_type,
      financial_year: "2026-27",
      remaining_days: 6
    )
  end

  it "suggests prorated salary and encashable leave as of the last working date" do
    result = described_class.new(employee: employee, last_working_date: last_working_date).call

    expect(result.salary_days).to eq(15)
    expect(result.earned_salary).to eq(9677.42)
    expect(result.leave_encashment_days).to eq(6)
    expect(result.leave_encashment).to eq(4000)
    expect(result.warnings).to be_empty
  end

  it "does not suggest salary already covered by approved regular payroll" do
    regular_run = create(:payroll_run, :approved, tenant: tenant, month: 8, year: 2026)
    create(:payslip, tenant: tenant, employee: employee, payroll_run: regular_run, month: 8, year: 2026)

    result = described_class.new(employee: employee, last_working_date: last_working_date).call

    expect(result.earned_salary).to eq(0)
    expect(result.warnings.join).to include("already includes this employee")
  end

  it "still suggests salary when the only regular run for the month was rejected" do
    rejected_run = create(:payroll_run, :rejected, tenant: tenant, month: 8, year: 2026)
    create(:payslip, tenant: tenant, employee: employee, payroll_run: rejected_run, month: 8, year: 2026)

    result = described_class.new(employee: employee, last_working_date: last_working_date).call

    expect(result.earned_salary).to eq(9677.42)
    expect(result.warnings).to be_empty
  end
end
