require "rails_helper"

RSpec.describe "EmployeePortal::TeamCalendar", type: :request do
  let(:tenant)         { create(:tenant, :active) }
  let(:dept)           { create(:department, tenant: tenant, name: "Engineering") }
  let(:other_dept)     { create(:department, tenant: tenant, name: "Sales") }
  let(:viewer_user)    { create(:user, :employee) }
  let(:viewer)         { create(:employee, tenant: tenant, user: viewer_user, department: dept, first_name: "Viewer", email: "v@x.com") }
  let(:teammate)       { create(:employee, tenant: tenant, department: dept, first_name: "Teammate", email: "t@x.com") }
  let(:outsider)       { create(:employee, tenant: tenant, department: other_dept, first_name: "Outsider", email: "o@x.com") }
  let(:casual)         { create(:leave_type, :casual, tenant: tenant) }
  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: viewer_user)
      viewer
      teammate
      outsider
      create(:payroll_setting, tenant: tenant, week_off_pattern: "all_saturdays_sundays")
    end
    set_tenant(tenant)
    sign_in_as(viewer_user)
  end

  def make_leave(employee, from, to, status)
    ActsAsTenant.with_tenant(tenant) do
      lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: casual,
                 from_date: from, to_date: to, status: status)
      lr.save(validate: false)
    end
  end

  describe "GET /portal/team_calendar" do
    it "returns 200 and shows department teammates" do
      get employee_portal_team_calendar_path(month: 1, year: 2025), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Teammate")
    end

    it "does not show employees from another department" do
      get employee_portal_team_calendar_path(month: 1, year: 2025), headers: { "Host" => subdomain_host }
      expect(response.body).not_to include("Outsider")
    end

    it "shows a teammate's approved leave type code" do
      make_leave(teammate, Date.new(2025, 1, 6), Date.new(2025, 1, 7), :approved)
      get employee_portal_team_calendar_path(month: 1, year: 2025), headers: { "Host" => subdomain_host }
      expect(response.body).to include(casual.code)
    end

    it "defaults to the current month when no params given" do
      get employee_portal_team_calendar_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Date.today.strftime("%B %Y"))
    end
  end
end
