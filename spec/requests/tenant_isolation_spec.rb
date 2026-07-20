require "rails_helper"

# The highest-consequence invariant in a row-level multi-tenant app: a user may
# only ever act inside a tenant they are a member of. Devise authenticates
# globally and Rolify roles are not tenant-scoped, so neither of those alone
# establishes this — only TenantUser membership does.
RSpec.describe "Tenant isolation", type: :request do
  let(:acme)   { create(:tenant, :active, subdomain: "acme") }
  let(:globex) { create(:tenant, :active, subdomain: "globex") }

  let(:acme_host)   { "acme.lvh.me" }
  let(:globex_host) { "globex.lvh.me" }

  # An HR admin whose only membership is acme.
  let(:acme_admin) { create(:user, :hr_admin) }

  before do
    ActsAsTenant.with_tenant(acme) { create(:tenant_user, tenant: acme, user: acme_admin) }
  end

  describe "an admin of one tenant on another tenant's subdomain" do
    before do
      ActsAsTenant.with_tenant(globex) do
        create(:employee, tenant: globex, first_name: "Sensitive", last_name: "Victim",
                          email: "victim@globex.test", employee_code: "GBX001")
      end

      set_tenant(globex)
      post user_session_path,
           params: { user: { email: acme_admin.email, password: "password123" } },
           headers: { "Host" => globex_host }
    end

    it "cannot reach the other tenant's admin panel" do
      get "/admin/employees", headers: { "Host" => globex_host }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "does not expose the other tenant's employee data" do
      get "/admin/employees", headers: { "Host" => globex_host }
      follow_redirect!

      expect(response.body).not_to include("Sensitive")
      expect(response.body).not_to include("GBX001")
    end

    it "is signed out rather than left with a live session" do
      get "/admin/employees", headers: { "Host" => globex_host }

      # A second request with no further action must still be unauthenticated.
      get "/admin/employees", headers: { "Host" => globex_host }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "cannot reach the other tenant's employee portal either" do
      get "/portal", headers: { "Host" => globex_host }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "an admin on their own tenant's subdomain" do
    before do
      set_tenant(acme)
      sign_in_as(acme_admin)
    end

    it "is unaffected by the membership check" do
      get "/admin/employees", headers: { "Host" => acme_host }

      expect(response).to have_http_status(:ok)
    end
  end

  # AdminUserPolicy#destroy? requires super_admin, so this actor must be one --
  # an hr_admin is turned away by Pundit before the lookup is ever reached, which
  # would make this assert nothing about scoping.
  describe "revoking admin access" do
    let(:acme_super)   { create(:user, :super_admin) }
    let(:globex_admin) { create(:user, :hr_admin) }

    before do
      ActsAsTenant.with_tenant(acme)   { create(:tenant_user, tenant: acme, user: acme_super) }
      ActsAsTenant.with_tenant(globex) { create(:tenant_user, tenant: globex, user: globex_admin) }
      set_tenant(acme)
      sign_in_as(acme_super)
    end

    it "cannot target a user belonging to another tenant" do
      expect {
        delete "/admin/admin_users/#{globex_admin.id}", headers: { "Host" => acme_host }
      }.not_to change { globex_admin.reload.has_role?(:hr_admin) }.from(true)

      expect(ActsAsTenant.with_tenant(globex) {
        TenantUser.exists?(tenant: globex, user: globex_admin)
      }).to be true
    end
  end
end
