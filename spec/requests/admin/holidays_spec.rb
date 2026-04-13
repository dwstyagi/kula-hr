require "rails_helper"

RSpec.describe "Admin::Holidays", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user)   { create(:user, :super_admin) }
  let(:host)   { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: user) }
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /admin/holidays" do
    it "returns 200 and lists holidays" do
      ActsAsTenant.with_tenant(tenant) do
        create(:holiday, tenant: tenant, name: "Republic Day", date: Date.new(2027, 1, 26))
      end
      get admin_holidays_path, headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Republic Day")
    end
  end

  describe "GET /admin/holidays/new" do
    it "returns 200" do
      get new_admin_holiday_path, headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/holidays" do
    context "with valid params" do
      it "creates a holiday and redirects" do
        expect {
          post admin_holidays_path,
               params: { holiday: { name: "Diwali", date: "2027-10-20", is_active: true } },
               headers: { "Host" => host }
        }.to change { Holiday.count }.by(1)

        expect(response).to redirect_to(admin_holidays_path)
        expect(flash[:notice]).to eq("Holiday created successfully.")
      end
    end

    context "with invalid params (blank name)" do
      it "re-renders new with errors" do
        post admin_holidays_path,
             params: { holiday: { name: "", date: "2027-10-20" } },
             headers: { "Host" => host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with duplicate date for the same tenant" do
      before do
        ActsAsTenant.with_tenant(tenant) { create(:holiday, tenant: tenant, date: "2027-10-20") }
      end

      it "re-renders new with uniqueness error" do
        post admin_holidays_path,
             params: { holiday: { name: "Another Holiday", date: "2027-10-20" } },
             headers: { "Host" => host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /admin/holidays/:id/edit" do
    it "returns 200" do
      holiday = ActsAsTenant.with_tenant(tenant) { create(:holiday, tenant: tenant) }
      get edit_admin_holiday_path(holiday), headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/holidays/:id" do
    let!(:holiday) { ActsAsTenant.with_tenant(tenant) { create(:holiday, tenant: tenant, name: "Old Name") } }

    context "with valid params" do
      it "updates and redirects" do
        patch admin_holiday_path(holiday),
              params: { holiday: { name: "New Name" } },
              headers: { "Host" => host }
        expect(response).to redirect_to(admin_holidays_path)
        expect(holiday.reload.name).to eq("New Name")
      end
    end

    context "with invalid params" do
      it "re-renders edit" do
        patch admin_holiday_path(holiday),
              params: { holiday: { name: "" } },
              headers: { "Host" => host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /admin/holidays/:id" do
    it "destroys the holiday and redirects" do
      holiday = ActsAsTenant.with_tenant(tenant) { create(:holiday, tenant: tenant) }
      expect {
        delete admin_holiday_path(holiday), headers: { "Host" => host }
      }.to change { Holiday.count }.by(-1)
      expect(response).to redirect_to(admin_holidays_path)
    end
  end

  describe "PATCH /admin/holidays/:id/toggle_active" do
    it "toggles active status on and off" do
      holiday = ActsAsTenant.with_tenant(tenant) { create(:holiday, tenant: tenant, is_active: true) }

      patch toggle_active_admin_holiday_path(holiday), headers: { "Host" => host }
      expect(holiday.reload.is_active).to be false

      patch toggle_active_admin_holiday_path(holiday), headers: { "Host" => host }
      expect(holiday.reload.is_active).to be true
    end
  end
end
