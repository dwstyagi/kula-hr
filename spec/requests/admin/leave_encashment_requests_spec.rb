require "rails_helper"

RSpec.describe "Admin::LeaveEncashmentRequests", type: :request do
  let(:tenant)   { create(:tenant, :active) }
  let(:user)     { create(:user, :hr_admin) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:host)     { { "Host" => "#{tenant.subdomain}.lvh.me" } }
  let!(:request_record) do
    ActsAsTenant.with_tenant(tenant) do
      r = build(:leave_encashment_request, tenant: tenant, employee: employee)
      r.save(validate: false)
      r
    end
  end

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: user) }
    set_tenant(tenant)
    sign_in_as(user)
  end

  it "lists requests" do
    get admin_leave_encashment_requests_path, headers: host
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(employee.full_name)
  end

  it "approves with the calculated amount" do
    allow_any_instance_of(Leave::EncashmentCalculator).to receive(:call).and_return(BigDecimal("6000"))
    patch approve_admin_leave_encashment_request_path(request_record), headers: host
    expect(response).to redirect_to(admin_leave_encashment_requests_path)
    expect(request_record.reload).to be_approved
    expect(request_record.encashment_amount).to eq(6000)
  end

  it "does not re-approve a decided request" do
    request_record.update_columns(status: LeaveEncashmentRequest.statuses[:rejected])
    patch approve_admin_leave_encashment_request_path(request_record), headers: host
    expect(request_record.reload).to be_rejected
    expect(flash[:alert]).to match(/Only pending/)
  end

  it "is not available to employees" do
    # Sign the HR user out first: Devise ignores a second sign-in while one
    # session is active, which would leave the request running as HR.
    delete destroy_user_session_path, headers: host
    sign_in_as(create(:user, :employee).tap { |u| ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: u) } })
    get admin_leave_encashment_requests_path, headers: host
    expect(response).to be_redirect
  end
end
