require "rails_helper"

RSpec.describe "Main branch review reproductions", type: :request do
  let(:tenant) { create(:tenant, :active) }
  before do
    travel_to Time.zone.local(2026, 10, 18, 12)
    set_tenant(tenant)
  end
  after { travel_back }

  it "keeps a resigned employee eligible for final-month payroll through employee update" do
    admin = create(:user, :super_admin)
    create(:tenant_user, tenant: tenant, user: admin)
    employee = create(:employee, tenant: tenant)
    sign_in_as(admin)
    patch admin_employee_path(employee), params: { employee: {
      employment_status: "resigned", last_working_date: "2026-10-20"
    } }, headers: { "Host" => "#{tenant.subdomain}.lvh.me" }
    expect(response).to have_http_status(:redirect)
    expect(Employee.payable_in(Date.new(2026, 10, 1))).to include(employee.reload)
  end

  it "uses the salary effective in the payroll month" do
    setting = create(:payroll_setting, tenant: tenant, pf_enabled: false,
      esi_enabled: false, pt_enabled: false, tds_enabled: false)
    employee = create(:employee, tenant: tenant)
    structure = create(:salary_structure, tenant: tenant)
    component = create(:salary_component, tenant: tenant, name: "Basic", calculation_type: "percentage")
    create(:salary_structure_component, salary_structure: structure, salary_component: component, value: 100)
    create(:employee_salary, tenant: tenant, employee: employee, salary_structure: structure,
      annual_ctc: 600_000, effective_from: Date.new(2026, 4, 1), effective_to: Date.new(2026, 10, 31))
    create(:employee_salary, tenant: tenant, employee: employee, salary_structure: structure,
      annual_ctc: 1_200_000, effective_from: Date.new(2026, 11, 1))
    create(:attendance_summary, tenant: tenant, employee: employee, month: 10, year: 2026,
      total_working_days: 22, days_present: 22, status: :locked)
    run = PayrollRun.new(tenant: tenant, month: 10, year: 2026)
    result = Payroll::SalaryCalculator.new(employee: employee, payroll_run: run, payroll_setting: setting).call
    expect(result.gross_pay).to eq(50_000)
  end

  it "allows leave on another location's holiday" do
    create(:payroll_setting, tenant: tenant)
    own_location = create(:work_location, tenant: tenant)
    other_location = create(:work_location, tenant: tenant)
    employee = create(:employee, tenant: tenant, work_location: own_location)
    leave_type = create(:leave_type, tenant: tenant)
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type)
    day = Date.new(2026, 10, 19)
    create(:holiday, tenant: tenant, work_location: other_location, date: day)
    request = LeaveRequest.new(tenant: tenant, employee: employee, leave_type: leave_type,
      from_date: day, to_date: day)
    expect(request.valid?).to eq(true), request.errors.full_messages.join(", ")
  end

  it "does not debit twice when manager approvals both loaded pending state" do
    employee = create(:employee, tenant: tenant)
    leave_type = create(:leave_type, tenant: tenant)
    balance = create(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type)
    request = create(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
      from_date: Date.new(2026, 10, 19), to_date: Date.new(2026, 10, 19))
    first = LeaveRequest.find(request.id)
    second = LeaveRequest.find(request.id)
    expect(first.pending? && second.pending?).to eq(true)
    # Both controller calls passed pending? before either transaction starts.
    [ first, second ].each do |loaded_request|
      ActiveRecord::Base.transaction do
        Leave::LeaveBalanceAdjuster.new(leave_request: loaded_request).debit!
        loaded_request.update!(status: :approved)
      end
    end
    expect(balance.reload.used_days).to eq(1)
  end
end
