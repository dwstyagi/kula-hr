require "rails_helper"

# Guards EmployeePortal::BaseController#require_employee! — the portal must only
# admit users backed by an Employee record. See docs/MANUAL_TEST_TRACKER.md ISSUE-1.
RSpec.describe "EmployeePortal access guard", type: :request do
  let(:tenant)         { create(:tenant, :active) }
  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }

  before { set_tenant(tenant) }

  context "as a user with an employee record" do
    let(:emp_user)  { create(:user, :employee) }
    let!(:employee) { create(:employee, tenant: tenant, user: emp_user) }

    before do
      ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: emp_user) }
      sign_in_as(emp_user)
    end

    it "allows access to the portal" do
      get employee_portal_leave_requests_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  context "as an admin user with no employee record" do
    let(:admin_user) { create(:user, :super_admin) }

    before do
      ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: admin_user) }
      sign_in_as(admin_user)
    end

    it "redirects portal requests to the admin panel instead of rendering" do
      get employee_portal_root_path, headers: { "Host" => subdomain_host }
      expect(response).to redirect_to(admin_root_path)
    end

    it "never serves the portal page (no 200)" do
      get employee_portal_root_path, headers: { "Host" => subdomain_host }
      expect(response).not_to have_http_status(:ok)
    end
  end

  context "as an authenticated user that is neither an employee nor an admin" do
    let(:orphan_user) { create(:user) }

    before do
      ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: orphan_user) }
      sign_in_as(orphan_user)
    end

    it "signs the user out and redirects to sign in" do
      get employee_portal_root_path, headers: { "Host" => subdomain_host }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
