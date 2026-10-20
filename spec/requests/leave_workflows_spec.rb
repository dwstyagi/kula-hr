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

  it "renders HR request, balance, adjustment and employee details screens" do
    request = create_request(duration: "morning")
    login(admin)
    get admin_leave_requests_path, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("0.5", "Employee name or code", "Cancellation requests")
    get new_admin_leave_request_path, headers: headers
    expect(response).to have_http_status(:ok)
    get admin_leave_balances_path, headers: headers
    expect(response).to have_http_status(:ok)
    get admin_leave_balance_path(balance), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Adjust balance")
    get admin_leave_request_path(request), headers: headers
    expect(response).to have_http_status(:ok)
    login(employee_user)
    get employee_portal_leave_request_path(request), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Half day", "morning", "Request history")
    get employee_portal_leave_balance_path(balance), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Record adjustment")
  end

  it "supports the employee half-day submit, HR approve, employee cancellation and HR refund flow" do
    login(employee_user)
    post employee_portal_leave_requests_path, headers: headers, params: { leave_request: { leave_type_id: type.id, from_date: date, to_date: date, duration: "afternoon", reason: "Appointment" } }
    request = LeaveRequest.last
    expect(request.number_of_days).to eq(0.5)
    login(admin)
    patch approve_admin_leave_request_path(request), headers: headers
    expect(request.reload).to be_approved
    login(employee_user)
    patch request_cancellation_employee_portal_leave_request_path(request), headers: headers, params: { reason: "Appointment moved" }
    expect(request.reload).to be_cancellation_pending
    expect(balance.reload.remaining_days).to eq(11.5)
    login(admin)
    get admin_leave_request_path(request), headers: headers
    expect(response.body).to include('id="cancellation_approval_reason"', 'id="cancellation_rejection_reason"')
    get admin_leave_requests_path(status: "cancellation_requested"), headers: headers
    expect(response.body).to include(employee.full_name)
    patch cancel_admin_leave_request_path(request), headers: headers, params: { reason: "Accepted by HR" }
    expect(request.reload).to be_cancelled
    expect(balance.reload.remaining_days).to eq(12)
    expect(request.leave_request_events.last.actor).to eq(admin)
  end

  it "allows HR to record a backdated request on an employee's behalf" do
    login(admin)
    post admin_leave_requests_path, headers: headers, params: { employee_code: employee.employee_code,
      leave_request: { leave_type_id: type.id, from_date: date - 7, to_date: date - 7, regularization_note: "Sick leave reported late" } }
    expect(response).to redirect_to(admin_leave_requests_path)
    request = LeaveRequest.last
    expect(request).to be_regularization
    expect(request.leave_request_events.first.actor).to eq(admin)
  end

  it "filters employee names, date overlap and leave type, preserving filters on status links" do
    matching = create_request
    other = create(:employee, tenant: tenant, first_name: "Different", last_name: "Person")
    create(:leave_balance, tenant: tenant, employee: other, leave_type: type)
    create(:leave_request, tenant: tenant, employee: other, leave_type: type, from_date: date, to_date: date)
    login(admin)
    get admin_leave_requests_path(employee: "LeaveTest Employee", from_date: date, to_date: date, leave_type_id: type.id), headers: headers
    expect(response.body).to include("leave_request_#{matching.id}")
    expect(response.body).not_to include(other.full_name)
    get admin_leave_requests_path(employee: employee.employee_code, from_date: date + 1), headers: headers
    expect(response.body).not_to include("leave_request_#{matching.id}")
    get admin_leave_requests_path(from_date: "bad-date", status: "bogus"), headers: headers
    expect(response).to have_http_status(:ok)
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

  it "prevents an employee from reading another employee's details or posting an HR adjustment" do
    other = create(:employee, tenant: tenant)
    other_balance = create(:leave_balance, tenant: tenant, employee: other, leave_type: type)
    other_request = create(:leave_request, tenant: tenant, employee: other, leave_type: type, from_date: date, to_date: date)
    login(employee_user)
    get employee_portal_leave_request_path(other_request), headers: headers
    expect(response).to have_http_status(:not_found)
    get employee_portal_leave_balance_path(other_balance), headers: headers
    expect(response).to have_http_status(:not_found)
    post adjust_admin_leave_balance_path(balance), headers: headers, params: { days: "5", reason: "Unauthorized", reference: SecureRandom.uuid }
    expect(balance.reload.remaining_days).to eq(12)
  end

  it "records an authorized HR adjustment with its actor and prevents duplicate submissions" do
    login(admin)
    params = { days: "-0.5", reason: "Imported opening correction", reference: SecureRandom.uuid }
    2.times { post adjust_admin_leave_balance_path(balance), headers: headers, params: params }
    expect(balance.reload.remaining_days).to eq(11.5)
    expect(balance.leave_balance_entries.last.actor).to eq(admin)
    expect(balance.leave_balance_entries.where(kind: "hr_adjustment").count).to eq(1)
  end
  it "blocks a manager from approving backdated regularization but lets HR review it" do
    manager = create(:employee, :with_user, tenant: tenant)
    employee.update!(leave_approver: :reporting_manager, reporting_manager: manager)
    request = create(:leave_request, tenant: tenant, employee: employee, leave_type: type, from_date: date - 7, to_date: date - 7, regularization_note: "Emergency illness")
    login(manager.user)
    patch approve_employee_portal_team_leave_request_path(request), headers: headers
    expect(request.reload).to be_pending
    expect(flash[:alert]).to include("HR approval")
    login(admin)
    patch approve_admin_leave_request_path(request), headers: headers
    expect(request.reload).to be_approved
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

  it "prevents cross-tenant access to balances and requests" do
    other_tenant = create(:tenant, :active)
    foreign_balance, foreign_request = ActsAsTenant.with_tenant(other_tenant) do
      emp = create(:employee, tenant: other_tenant)
      leave_type = create(:leave_type, :casual, tenant: other_tenant)
      bal = create(:leave_balance, tenant: other_tenant, employee: emp, leave_type: leave_type)
      req = create(:leave_request, tenant: other_tenant, employee: emp, leave_type: leave_type, from_date: date, to_date: date)
      [ bal, req ]
    end
    login(admin)
    get admin_leave_balance_path(foreign_balance), headers: headers
    expect(response).to have_http_status(:not_found)
    get admin_leave_request_path(foreign_request), headers: headers
    expect(response).to have_http_status(:not_found)
  end
  it "returns a validation error for an unsupported duration instead of raising" do
    login(employee_user)
    post employee_portal_leave_requests_path, headers: headers, params: { leave_request: { leave_type_id: type.id, from_date: date, to_date: date, duration: "invalid" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(LeaveRequest.count).to eq(0)
  end
end
