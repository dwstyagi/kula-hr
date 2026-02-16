require "rails_helper"

RSpec.describe "Platform::Tenants", type: :request do
  let!(:admin) { create(:platform_admin) }
  let!(:tenant) { create(:tenant, name: "Test Corp", subdomain: "testcorp") }

  before { login_as_platform_admin(admin) }

  describe "GET /platform_admin/tenants" do
    it "lists all tenants" do
      get platform_admin_tenants_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Test Corp")
    end
  end

  describe "GET /platform_admin/tenants/:id" do
    it "shows tenant details" do
      get platform_admin_tenant_path(tenant)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Test Corp")
    end
  end

  describe "GET /platform_admin/tenants/:id/edit" do
    it "renders the edit form" do
      get edit_platform_admin_tenant_path(tenant)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /platform_admin/tenants/:id" do
    context "with valid params" do
      it "updates the tenant" do
        patch platform_admin_tenant_path(tenant), params: { tenant: { name: "Updated Corp" } }
        expect(response).to redirect_to(platform_admin_tenant_path(tenant))
        expect(tenant.reload.name).to eq("Updated Corp")
      end
    end

    context "with invalid params" do
      it "re-renders edit form" do
        patch platform_admin_tenant_path(tenant), params: { tenant: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /platform_admin/tenants/:id/toggle_status" do
    it "activates a trial tenant" do
      patch toggle_status_platform_admin_tenant_path(tenant)
      expect(tenant.reload.status).to eq("active")
      expect(response).to redirect_to(platform_admin_tenants_path)
    end

    it "suspends an active tenant" do
      tenant.update!(status: "active")
      patch toggle_status_platform_admin_tenant_path(tenant)
      expect(tenant.reload.status).to eq("suspended")
    end

    it "activates a suspended tenant" do
      tenant.update!(status: "suspended")
      patch toggle_status_platform_admin_tenant_path(tenant)
      expect(tenant.reload.status).to eq("active")
    end
  end

  context "when not logged in" do
    before { delete platform_admin_logout_path }

    it "redirects to login" do
      get platform_admin_tenants_path
      expect(response).to redirect_to(platform_admin_login_path)
    end
  end
end
