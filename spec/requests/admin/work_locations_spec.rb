require "rails_helper"

RSpec.describe "Admin::WorkLocations", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user)   { create(:user, :super_admin) }
  let(:host)   { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: user) }
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /admin/work_locations" do
    it "returns 200 and lists locations" do
      ActsAsTenant.with_tenant(tenant) { create(:work_location, tenant: tenant, name: "Mumbai Office") }
      get admin_work_locations_path, headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mumbai Office")
    end
  end

  describe "GET /admin/work_locations/new" do
    it "returns 200" do
      get new_admin_work_location_path, headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/work_locations" do
    it "creates a location and redirects" do
      expect {
        post admin_work_locations_path,
             params: { work_location: { name: "Bengaluru Office", state: "Karnataka", is_active: true } },
             headers: { "Host" => host }
      }.to change { WorkLocation.count }.by(1)
      expect(response).to redirect_to(admin_work_locations_path)
    end

    it "re-renders on invalid params" do
      post admin_work_locations_path,
           params: { work_location: { name: "" } },
           headers: { "Host" => host }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /admin/work_locations/:id" do
    it "updates the location" do
      location = ActsAsTenant.with_tenant(tenant) { create(:work_location, tenant: tenant, name: "Old") }
      patch admin_work_location_path(location),
            params: { work_location: { name: "New" } },
            headers: { "Host" => host }
      expect(location.reload.name).to eq("New")
    end
  end

  describe "DELETE /admin/work_locations/:id" do
    it "deletes the location" do
      location = ActsAsTenant.with_tenant(tenant) { create(:work_location, tenant: tenant) }
      expect {
        delete admin_work_location_path(location), headers: { "Host" => host }
      }.to change { WorkLocation.count }.by(-1)
    end
  end
end
