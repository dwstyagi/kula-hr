require "rails_helper"

RSpec.describe "EmployeePortal::Dashboard", type: :request do
  let(:tenant)   { create(:tenant, :active) }
  let(:emp_user) { create(:user, :employee) }
  let(:employee) { create(:employee, tenant: tenant, user: emp_user) }
  let(:host)     { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: emp_user) }
    set_tenant(tenant)
    employee
    sign_in_as(emp_user)
  end

  describe "GET /portal (completeness meters)" do
    it "shows profile completeness" do
      get employee_portal_root_path, headers: { "Host" => host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Profile Status")
      expect(response.body).to include("% Complete")
    end

    it "shows tax declaration completeness alongside the tax summary" do
      ActsAsTenant.with_tenant(tenant) do
        create(:tax_declaration, tenant: tenant, employee: employee,
               financial_year: current_financial_year)
      end

      get employee_portal_root_path, headers: { "Host" => host }
      expect(response.body).to include("Declaration completeness")
      expect(response.body).to include("0% complete")
      expect(response.body).to include("Finish your declaration")
    end

    it "shows 100% complete once the declaration is submitted" do
      ActsAsTenant.with_tenant(tenant) do
        create(:tax_declaration, :submitted, tenant: tenant, employee: employee,
               financial_year: current_financial_year)
      end

      get employee_portal_root_path, headers: { "Host" => host }
      expect(response.body).to include("100% complete")
      expect(response.body).not_to include("Finish your declaration")
    end
  end

  describe "GET /portal (tax declaration deadline nudge)" do
    it "warns with the financial-year-end date while the declaration is a draft" do
      ActsAsTenant.with_tenant(tenant) do
        create(:tax_declaration, tenant: tenant, employee: employee,
               financial_year: current_financial_year)
      end

      fy_end = Date.new(current_financial_year[0, 4].to_i + 1, 3, 31)

      get employee_portal_root_path, headers: { "Host" => host }
      expect(response.body).to include("Tax declaration still in draft")
      expect(response.body).to include(fy_end.strftime("%d %b %Y"))
    end

    it "does not show the draft warning once submitted" do
      ActsAsTenant.with_tenant(tenant) do
        create(:tax_declaration, :submitted, tenant: tenant, employee: employee,
               financial_year: current_financial_year)
      end

      get employee_portal_root_path, headers: { "Host" => host }
      expect(response.body).not_to include("Tax declaration still in draft")
    end
  end

  def current_financial_year
    today = Date.current
    if today.month >= 4
      "#{today.year}-#{(today.year + 1).to_s.last(2)}"
    else
      "#{today.year - 1}-#{today.year.to_s.last(2)}"
    end
  end
end
