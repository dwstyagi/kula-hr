require "rails_helper"

RSpec.describe "Admin::SalaryComponents", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user)   { create(:user, :super_admin) }

  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: user)
    end
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /admin/salary_components" do
    it "returns 200 and displays components grouped by type" do
      ActsAsTenant.with_tenant(tenant) do
        create(:salary_component, :earning, tenant: tenant, name: "Basic")
        create(:salary_component, :deduction, tenant: tenant, name: "PF")
      end

      get admin_salary_components_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Basic")
      expect(response.body).to include("PF")
      expect(response.body).to include("Earnings")
      expect(response.body).to include("Deductions")
    end
  end

  describe "GET /admin/salary_components/new" do
    it "returns 200" do
      get new_admin_salary_component_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/salary_components" do
    context "with valid params" do
      it "creates a component and redirects" do
        expect {
          post admin_salary_components_path,
               params: { salary_component: { name: "Bonus", component_type: "earning", calculation_type: "flat", taxable: true, sort_order: 5 } },
               headers: { "Host" => subdomain_host }
        }.to change { SalaryComponent.count }.by(1)

        expect(response).to redirect_to(admin_salary_components_path)
        expect(flash[:notice]).to eq("Salary component created successfully.")
      end
    end

    context "with invalid params" do
      it "re-renders new with errors" do
        post admin_salary_components_path,
             params: { salary_component: { name: "", component_type: "earning", calculation_type: "flat" } },
             headers: { "Host" => subdomain_host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /admin/salary_components/:id/edit" do
    it "returns 200" do
      component = ActsAsTenant.with_tenant(tenant) { create(:salary_component, tenant: tenant) }
      get edit_admin_salary_component_path(component), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/salary_components/:id" do
    let!(:component) { ActsAsTenant.with_tenant(tenant) { create(:salary_component, tenant: tenant, name: "Old Name") } }

    context "with valid params" do
      it "updates and redirects" do
        patch admin_salary_component_path(component),
              params: { salary_component: { name: "New Name" } },
              headers: { "Host" => subdomain_host }

        expect(response).to redirect_to(admin_salary_components_path)
        expect(component.reload.name).to eq("New Name")
      end
    end

    context "with invalid params" do
      it "re-renders edit" do
        patch admin_salary_component_path(component),
              params: { salary_component: { name: "" } },
              headers: { "Host" => subdomain_host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /admin/salary_components/:id" do
    it "destroys the component and redirects" do
      component = ActsAsTenant.with_tenant(tenant) { create(:salary_component, tenant: tenant) }

      expect {
        delete admin_salary_component_path(component), headers: { "Host" => subdomain_host }
      }.to change { SalaryComponent.count }.by(-1)

      expect(response).to redirect_to(admin_salary_components_path)
    end
  end

  describe "PATCH /admin/salary_components/:id/toggle_active" do
    it "toggles active status" do
      component = ActsAsTenant.with_tenant(tenant) { create(:salary_component, tenant: tenant, active: true) }

      patch toggle_active_admin_salary_component_path(component), headers: { "Host" => subdomain_host }
      expect(component.reload.active).to be false

      patch toggle_active_admin_salary_component_path(component), headers: { "Host" => subdomain_host }
      expect(component.reload.active).to be true
    end
  end
end
