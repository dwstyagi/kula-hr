require "rails_helper"

RSpec.describe "EmployeePortal::Profiles", type: :request do
  let(:tenant)       { create(:tenant, :active) }
  let(:emp_user)     { create(:user, :employee) }
  let(:employee)     { create(:employee, tenant: tenant, user: emp_user) }
  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: emp_user) }
    set_tenant(tenant)
    employee
    sign_in_as(emp_user)
  end

  describe "GET /portal/profile" do
    it "returns 200" do
      get employee_portal_profile_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /portal/profile/edit" do
    it "returns 200" do
      get edit_employee_portal_profile_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /portal/profile" do
    it "updates allowed fields and redirects" do
      patch employee_portal_profile_path,
            params: { employee: { phone: "9876543210", bank_account_number: "1234567890" } },
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(employee_portal_profile_path)
      employee.reload
      expect(employee.phone).to eq("9876543210")
      expect(employee.bank_account_number).to eq("1234567890")
    end

    it "re-renders edit on validation error" do
      patch employee_portal_profile_path,
            params: { employee: { pan_number: "INVALID" } },
            headers: { "Host" => subdomain_host }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "authorization" do
    it "prevents updating protected fields like employee_code" do
      original_code = employee.employee_code
      original_status = employee.employment_status

      patch employee_portal_profile_path,
            params: { employee: { employee_code: "HACK001", employment_status: "terminated", phone: "1111111111" } },
            headers: { "Host" => subdomain_host }

      employee.reload
      expect(employee.employee_code).to eq(original_code)
      expect(employee.employment_status).to eq(original_status)
      expect(employee.phone).to eq("1111111111")
    end
  end
end
