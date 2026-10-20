require "rails_helper"

RSpec.describe "Leave workflow access and screens", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:admin) { create(:user, :super_admin) }
  let(:employee_user) { create(:user, :employee) }
  let(:employee) { create(:employee, tenant: tenant, user: employee_user, first_name: "LeaveTest", last_name: "Employee") }
  let(:type) { create(:leave_type, :casual, tenant: tenant) }
  let!(:balance) { create(:leave_balance, tenant: tenant, employee: employee, leave_type: type, total_days: 12, remaining_days: 12, used_days: 0) }
  let(:date) { Date.new(2026, 10, 22) }
  let(:headers) { { "Host" => "#{tenant.subdomain}.lvh.me" } }
  before do
    set_tenant(tenant)
    create(:tenant_user, tenant: tenant, user: admin)
    create(:tenant_user, tenant: tenant, user: employee_user)
  end
  around { |example| travel_to(Time.zone.local(2026, 10, 20, 12)) { example.run } }

  def login(user)
    delete destroy_user_session_path, headers: headers
    set_tenant(tenant)
    sign_in_as(user)
  end

  def create_request(**attributes)
    create(:leave_request, tenant: tenant, employee: employee, leave_type: type, from_date: date, to_date: date, **attributes)
  end

  it "blocks HR bulk approval against locked attendance" do
    request = create_request
    create(:attendance_summary, :locked, tenant: tenant, employee: employee, month: 10, year: 2026)
    login(admin)
    patch bulk_approve_admin_leave_requests_path, headers: headers, params: { ids: [ request.id ] }
    expect(request.reload).to be_pending
    expect(balance.reload.remaining_days).to eq(12)
    expect(flash[:alert]).to include("locked")
  end

  it "prevents a manager approval after attendance is locked" do
    manager = create(:employee, :with_user, tenant: tenant)
    employee.update!(leave_approver: :reporting_manager, reporting_manager: manager)
    request = create_request
    create(:attendance_summary, :locked, tenant: tenant, employee: employee, month: 10, year: 2026)
    login(manager.user)
    patch approve_employee_portal_team_leave_request_path(request), headers: headers
    expect(request.reload).to be_pending
    expect(flash[:alert]).to include("locked")
  end

  it "returns a validation error for an unsupported duration instead of raising" do
    login(employee_user)
    post employee_portal_leave_requests_path, headers: headers, params: { leave_request: { leave_type_id: type.id, from_date: date, to_date: date, duration: "invalid" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(LeaveRequest.count).to eq(0)
  end
end
