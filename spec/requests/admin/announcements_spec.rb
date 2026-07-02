require "rails_helper"

RSpec.describe "Admin::Announcements", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user)   { create(:user, :super_admin) }
  let(:host)   { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: user) }
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /admin/announcements" do
    it "returns 200 and lists announcements" do
      ActsAsTenant.with_tenant(tenant) { create(:announcement, tenant: tenant, title: "Diwali Party") }
      get admin_announcements_path, headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Diwali Party")
    end
  end

  describe "POST /admin/announcements" do
    it "creates an announcement authored by the current user" do
      expect {
        post admin_announcements_path,
             params: { announcement: { title: "New policy", body: "Details here" } },
             headers: { "Host" => host }
      }.to change { Announcement.count }.by(1)

      expect(response).to redirect_to(admin_announcements_path)
      expect(Announcement.last.author).to eq(user)
    end

    it "re-renders new when title is blank" do
      post admin_announcements_path,
           params: { announcement: { title: "" } },
           headers: { "Host" => host }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /admin/announcements/:id (edit with notify)" do
    let(:announcement) { ActsAsTenant.with_tenant(tenant) { create(:announcement, :published, tenant: tenant) } }
    let(:employee)     { ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) } }

    before { ActsAsTenant.with_tenant(tenant) { announcement.mark_read_by!(employee) } }

    it "clears read receipts and stamps last_edited_at when notify_readers is checked" do
      patch admin_announcement_path(announcement),
            params: { announcement: { title: "Corrected date" }, notify_readers: "1" },
            headers: { "Host" => host }

      expect(announcement.reload.last_edited_at).to be_present
      expect(announcement.announcement_reads.count).to eq(0)
    end

    it "keeps read receipts for a silent edit (notify_readers unchecked)" do
      patch admin_announcement_path(announcement),
            params: { announcement: { title: "Typo fix" } },
            headers: { "Host" => host }

      expect(announcement.reload.last_edited_at).to be_nil
      expect(announcement.announcement_reads.count).to eq(1)
    end
  end

  describe "PATCH /admin/announcements/:id/publish" do
    it "publishes the announcement" do
      announcement = ActsAsTenant.with_tenant(tenant) { create(:announcement, tenant: tenant) }
      patch publish_admin_announcement_path(announcement), headers: { "Host" => host }
      expect(announcement.reload.published).to be true
      expect(announcement.published_at).to be_present
    end
  end

  describe "DELETE /admin/announcements/:id" do
    it "destroys the announcement" do
      announcement = ActsAsTenant.with_tenant(tenant) { create(:announcement, tenant: tenant) }
      expect {
        delete admin_announcement_path(announcement), headers: { "Host" => host }
      }.to change { Announcement.count }.by(-1)
    end
  end

  context "when signed in as a non-admin employee" do
    let(:employee_user) { create(:user, :employee) }

    before do
      ActsAsTenant.with_tenant(tenant) do
        create(:tenant_user, tenant: tenant, user: employee_user)
        create(:employee, tenant: tenant, user: employee_user)
      end
    end

    it "redirects away from the admin panel" do
      delete destroy_user_session_path, headers: { "Host" => host }
      sign_in_as(employee_user)

      get admin_announcements_path, headers: { "Host" => host }
      expect(response).to be_redirect
    end
  end
end
