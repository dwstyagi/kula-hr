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

    it "lists holidays with the latest year/date first" do
      ActsAsTenant.with_tenant(tenant) do
        create(:holiday, tenant: tenant, name: "Older Holiday", date: Date.new(2026, 1, 26))
        create(:holiday, tenant: tenant, name: "Newer Holiday", date: Date.new(2027, 12, 25))
      end

      get admin_holidays_path, headers: { "Host" => host }
      expect(response.body.index("Newer Holiday")).to be < response.body.index("Older Holiday")
    end

    context "pagination" do
      before do
        ActsAsTenant.with_tenant(tenant) do
          15.times { |i| create(:holiday, tenant: tenant, name: "PagTestHoliday#{i}", date: Date.new(2027, 1, 1) + i) }
        end
      end

      def name_cell_count
        response.body.scan(/<td class="text-sm font-medium text-stone-900">PagTestHoliday/).size
      end

      it "defaults to 10 per page" do
        get admin_holidays_path, headers: { "Host" => host }
        expect(name_cell_count).to eq(10)
        expect(response.body).to include("Showing")
      end

      it "honors a valid per_page param" do
        get admin_holidays_path(per_page: 25), headers: { "Host" => host }
        expect(name_cell_count).to eq(15)
      end

      it "falls back to the default for an invalid per_page value" do
        get admin_holidays_path(per_page: 999), headers: { "Host" => host }
        expect(name_cell_count).to eq(10)
      end
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

  describe "POST /admin/holidays/add_standard_presets" do
    it "bulk-creates the standard holidays for the given year" do
      expect {
        post add_standard_presets_admin_holidays_path(year: 2026), headers: { "Host" => host }
      }.to change { Holiday.count }.by(Holidays::StandardPresets.for_year(2026).size)

      expect(response).to redirect_to(admin_holidays_path)
      expect(flash[:notice]).to include("Added")
    end

    it "skips dates that already have a holiday" do
      ActsAsTenant.with_tenant(tenant) { create(:holiday, tenant: tenant, name: "Republic Day", date: Date.new(2026, 1, 26)) }

      expect {
        post add_standard_presets_admin_holidays_path(year: 2026), headers: { "Host" => host }
      }.to change { Holiday.count }.by(Holidays::StandardPresets.for_year(2026).size - 1)
    end

    it "is idempotent when run twice" do
      post add_standard_presets_admin_holidays_path(year: 2026), headers: { "Host" => host }

      expect {
        post add_standard_presets_admin_holidays_path(year: 2026), headers: { "Host" => host }
      }.not_to change { Holiday.count }

      expect(flash[:notice]).to include("already on the calendar")
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
