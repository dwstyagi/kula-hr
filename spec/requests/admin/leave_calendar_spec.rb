require "rails_helper"

RSpec.describe "Admin::LeaveCalendar", type: :request do
  let(:tenant)         { create(:tenant, :active) }
  let(:user)           { create(:user, :super_admin) }
  let(:eng)            { create(:department, tenant: tenant, name: "Engineering") }
  let(:sales)          { create(:department, tenant: tenant, name: "Sales") }
  let(:dev)            { create(:employee, tenant: tenant, department: eng, first_name: "Dev", email: "d@x.com") }
  let(:rep)            { create(:employee, tenant: tenant, department: sales, first_name: "Rep", email: "r@x.com") }
  let(:host)           { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: user)
      create(:payroll_setting, tenant: tenant, week_off_pattern: "all_saturdays_sundays")
      dev
      rep
    end
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /admin/leave_calendar" do
    it "returns 200 and lists all employees" do
      get admin_leave_calendar_path(month: 1, year: 2025), headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dev")
      expect(response.body).to include("Rep")
    end

    it "filters by department" do
      get admin_leave_calendar_path(month: 1, year: 2025, department_id: eng.id), headers: { "Host" => host }
      expect(response.body).to include(dev.full_name)
      expect(response.body).not_to include(rep.full_name)
    end

    it "defaults to the current month with no params" do
      get admin_leave_calendar_path, headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Date.today.strftime("%B %Y"))
    end
  end
end
