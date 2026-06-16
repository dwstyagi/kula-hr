require "rails_helper"

# Integration test for the location-aware holiday change (gap #7):
# an approved LOP leave -> Attendance::SummaryGenerator (location-aware working
# days) -> AttendanceSummary -> Payroll::SalaryCalculator -> net pay.
#
# Proves that a holiday assigned to an employee's work location reduces their
# monthly working days, which changes the LOP proration and therefore net pay.
RSpec.describe "Location holiday flows into payroll", type: :service do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }

  before { set_tenant(tenant) }

  # Standard structure: Basic 40%, HRA 20%, Special 30%, Conveyance flat 1600
  let(:basic_comp)      { create(:salary_component, tenant: tenant, name: "Basic",                calculation_type: "percentage", sort_order: 1) }
  let(:hra_comp)        { create(:salary_component, tenant: tenant, name: "HRA",                  calculation_type: "percentage", sort_order: 2) }
  let(:special_comp)    { create(:salary_component, tenant: tenant, name: "Special Allowance",    calculation_type: "percentage", sort_order: 3) }
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
           week_off_pattern: "all_saturdays_sundays",
           pf_enabled: true, esi_enabled: true, pt_enabled: true, tds_enabled: true)
  end

  let!(:pt_slabs) do
    create(:professional_tax_slab, :mh_low,  tenant: tenant)
    create(:professional_tax_slab, :mh_mid,  tenant: tenant)
    create(:professional_tax_slab, :mh_high, tenant: tenant)
  end

  let(:lop_type) { create(:leave_type, :lop, tenant: tenant) }

  # Mumbai office with a location-only holiday on Jan 15, 2025 (a Wednesday).
  let(:mumbai) { create(:work_location, tenant: tenant, name: "Mumbai") }
  let!(:mumbai_holiday) { create(:holiday, tenant: tenant, date: Date.new(2025, 1, 15), name: "Local Festival", work_location: mumbai) }

  # Two employees, identical CTC: one company-wide, one at the Mumbai office.
  let(:company_emp) do
    create(:employee, tenant: tenant, employment_status: "active", email: "company@x.com",
           pan_number: "ABCDE1234F", pf_applicable: true, pt_applicable: true)
  end
  let(:mumbai_emp) do
    create(:employee, tenant: tenant, employment_status: "active", email: "mumbai@x.com",
           work_location: mumbai, pan_number: "ABCDE5678G", pf_applicable: true, pt_applicable: true)
  end

  let(:payroll_run) { create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 1, year: 2025) }

  def assign_salary(employee, annual_ctc: 1_200_000)
    create(:employee_salary, tenant: tenant, employee: employee,
           salary_structure: structure, annual_ctc: annual_ctc)
  end

  # One approved unpaid (LOP) day on Jan 8, 2025 (a Wednesday, working day for both).
  def add_one_lop_day(employee)
    lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: lop_type,
               from_date: Date.new(2025, 1, 8), to_date: Date.new(2025, 1, 8), status: :approved)
    lr.save(validate: false)
  end

  def result_for(employee)
    Payroll::SalaryCalculator.new(employee: employee, payroll_run: payroll_run, payroll_setting: setting).call
  end

  before do
    setting
    structure
    assign_salary(company_emp)
    assign_salary(mumbai_emp)
    add_one_lop_day(company_emp)
    add_one_lop_day(mumbai_emp)

    # Generate location-aware attendance summaries for the month.
    Attendance::SummaryGenerator.new(month: 1, year: 2025, tenant: tenant).call
  end

  it "gives the Mumbai employee fewer working days due to the location holiday" do
    expect(result_for(company_emp).attendance[:working_days]).to eq(23)  # Jan 2025, no holiday
    expect(result_for(mumbai_emp).attendance[:working_days]).to eq(22)   # minus Mumbai holiday
  end

  it "records exactly one LOP day for both employees" do
    expect(result_for(company_emp).attendance[:lop_days]).to eq(1)
    expect(result_for(mumbai_emp).attendance[:lop_days]).to eq(1)
  end

  it "prorates each employee against their own working-day count" do
    expect(result_for(company_emp).proration_factor).to be_within(0.0001).of(22.0 / 23) # ≈ 0.9565
    expect(result_for(mumbai_emp).proration_factor).to be_within(0.0001).of(21.0 / 22)  # ≈ 0.9545
  end

  it "produces a lower net pay for the Mumbai employee (1 LOP over fewer working days hits harder)" do
    company_net = result_for(company_emp).net_pay
    mumbai_net  = result_for(mumbai_emp).net_pay

    expect(mumbai_net).to be < company_net
    expect(company_net).to be > 0
  end
end
