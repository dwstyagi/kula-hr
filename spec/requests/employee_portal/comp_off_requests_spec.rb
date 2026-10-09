require "rails_helper"

RSpec.describe "EmployeePortal comp-off", type: :request do
  let(:tenant)    { create(:tenant, :active) }
  let(:mgr_user)  { create(:user, :employee) }
  let(:manager)   { create(:employee, tenant: tenant, user: mgr_user, email: "mgr@x.com") }
  let(:emp_user)  { create(:user, :employee) }
  let(:employee)  { create(:employee, tenant: tenant, user: emp_user, reporting_manager: manager) }
  let(:outsider)  { create(:employee, tenant: tenant, email: "other@x.com") }
  let(:host)      { { "Host" => "#{tenant.subdomain}.lvh.me" } }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: mgr_user)
      create(:tenant_user, tenant: tenant, user: emp_user)
      create(:leave_type, tenant: tenant, code: "CO", name: "Comp Off")
      employee
    end
    set_tenant(tenant)
  end

  def comp_off_for(person)
    ActsAsTenant.with_tenant(tenant) do
      r = build(:comp_off_request, tenant: tenant, employee: person)
      r.save(validate: false)
      r
    end
  end

  describe "as the employee" do
    before { sign_in_as(emp_user) }

    it "shows the comp-off list and the request form" do
      comp_off_for(employee)
      get employee_portal_comp_off_requests_path, headers: host
      expect(response).to have_http_status(:ok)
      get new_employee_portal_comp_off_request_path, headers: host
      expect(response).to have_http_status(:ok)
    end

    it "shows the encashment list" do
      get employee_portal_leave_encashment_requests_path, headers: host
      expect(response).to have_http_status(:ok)
    end
  end

  describe "as the reporting manager" do
    before { sign_in_as(mgr_user) }

    it "lists the team's requests" do
      comp_off_for(employee)
      get employee_portal_team_comp_off_requests_path, headers: host
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employee.full_name)
    end

    it "approves a direct report's request" do
      request_record = comp_off_for(employee)
      patch approve_employee_portal_team_comp_off_request_path(request_record), headers: host
      expect(request_record.reload).to be_approved
    end

    it "cannot reach someone else's request" do
      request_record = comp_off_for(outsider)
      patch approve_employee_portal_team_comp_off_request_path(request_record), headers: host
      expect(response).to have_http_status(:not_found)
      expect(request_record.reload).to be_pending
    end
  end
end
