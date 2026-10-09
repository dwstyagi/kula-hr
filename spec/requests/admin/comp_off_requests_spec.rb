require "rails_helper"

RSpec.describe "Admin::CompOffRequests", type: :request do
  let(:tenant)   { create(:tenant, :active) }
  let(:user)     { create(:user, :hr_admin) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:host)     { { "Host" => "#{tenant.subdomain}.lvh.me" } }
  let!(:comp_off_type) { ActsAsTenant.with_tenant(tenant) { create(:leave_type, tenant: tenant, code: "CO", name: "Comp Off") } }
  let!(:request_record) do
    ActsAsTenant.with_tenant(tenant) do
      r = build(:comp_off_request, tenant: tenant, employee: employee)
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
    get admin_comp_off_requests_path, headers: host
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(employee.full_name)
  end

  it "approves once and credits one day" do
    patch approve_admin_comp_off_request_path(request_record), headers: host
    expect(response).to redirect_to(admin_comp_off_requests_path)
    expect(request_record.reload).to be_approved

    patch approve_admin_comp_off_request_path(request_record), headers: host
    balance = ActsAsTenant.with_tenant(tenant) { LeaveBalance.find_by(employee: employee, leave_type: comp_off_type) }
    expect(balance.remaining_days).to eq(1)
    expect(flash[:alert]).to match(/Only pending/)
  end

  it "rejects with a reason" do
    patch reject_admin_comp_off_request_path(request_record), params: { rejection_reason: "Not a holiday" }, headers: host
    expect(request_record.reload).to be_rejected
    expect(request_record.rejection_reason).to eq("Not a holiday")
  end
end
