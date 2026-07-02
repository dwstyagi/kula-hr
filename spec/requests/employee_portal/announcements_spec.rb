require "rails_helper"

RSpec.describe "EmployeePortal::Announcements", type: :request do
  let(:tenant)   { create(:tenant, :active) }
  let(:user)     { create(:user, :employee) }
  let(:host)     { "#{tenant.subdomain}.lvh.me" }
  let!(:employee) do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: user)
      create(:employee, tenant: tenant, user: user)
    end
  end

  before do
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /portal/announcements" do
    it "lists published announcements but not drafts" do
      ActsAsTenant.with_tenant(tenant) do
        create(:announcement, :published, tenant: tenant, title: "Company Picnic")
        create(:announcement, tenant: tenant, title: "Secret Draft")
      end

      get employee_portal_announcements_path, headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Company Picnic")
      expect(response.body).not_to include("Secret Draft")
    end
  end

  describe "GET /portal/announcements/:id" do
    it "shows a published announcement and marks it read" do
      announcement = ActsAsTenant.with_tenant(tenant) { create(:announcement, :published, tenant: tenant) }

      expect {
        get employee_portal_announcement_path(announcement), headers: { "Host" => host }
      }.to change { announcement.announcement_reads.count }.by(1)
      expect(response).to have_http_status(:ok)
    end

    it "does not expose a draft announcement" do
      announcement = ActsAsTenant.with_tenant(tenant) { create(:announcement, tenant: tenant) }
      get employee_portal_announcement_path(announcement), headers: { "Host" => host }
      expect(response).to have_http_status(:not_found)
    end
  end
end
