require "rails_helper"

RSpec.describe "Admin::SalaryStructures", type: :request do
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

  describe "GET /admin/salary_structures" do
    it "returns 200 and lists structures" do
      ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant, name: "Standard CTC") }

      get admin_salary_structures_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Standard CTC")
    end
  end

  describe "GET /admin/salary_structures/:id" do
    it "returns 200 and shows structure with components" do
      structure = ActsAsTenant.with_tenant(tenant) do
        s = create(:salary_structure, tenant: tenant, name: "Standard CTC")
        comp = create(:salary_component, tenant: tenant, name: "Basic", calculation_type: "percentage")
        create(:salary_structure_component, salary_structure: s, salary_component: comp, value: 40)
        s
      end

      get admin_salary_structure_path(structure), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Standard CTC")
      expect(response.body).to include("Basic")
      # value is now rendered as an inline-editable field + a "% of CTC" label
      expect(response.body).to include("% of CTC")
      expect(response.body).to include('value="40.0"')
    end
  end

  describe "GET /admin/salary_structures/new" do
    it "returns 200" do
      get new_admin_salary_structure_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/salary_structures" do
    context "with valid params" do
      it "creates a structure and redirects to show" do
        expect {
          post admin_salary_structures_path,
               params: { salary_structure: { name: "Standard CTC" } },
               headers: { "Host" => subdomain_host }
        }.to change { SalaryStructure.count }.by(1)

        structure = SalaryStructure.last
        expect(response).to redirect_to(admin_salary_structure_path(structure))
      end
    end

    context "with invalid params" do
      it "re-renders new with errors" do
        post admin_salary_structures_path,
             params: { salary_structure: { name: "" } },
             headers: { "Host" => subdomain_host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /admin/salary_structures/:id" do
    let!(:structure) { ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant, name: "Old Name") } }

    context "with valid params" do
      it "updates and redirects to show" do
        patch admin_salary_structure_path(structure),
              params: { salary_structure: { name: "New Name" } },
              headers: { "Host" => subdomain_host }

        expect(response).to redirect_to(admin_salary_structure_path(structure))
        expect(structure.reload.name).to eq("New Name")
      end
    end

    context "with invalid params" do
      it "re-renders edit" do
        patch admin_salary_structure_path(structure),
              params: { salary_structure: { name: "" } },
              headers: { "Host" => subdomain_host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /admin/salary_structures/:id" do
    it "destroys the structure and redirects" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant) }

      expect {
        delete admin_salary_structure_path(structure), headers: { "Host" => subdomain_host }
      }.to change { SalaryStructure.count }.by(-1)

      expect(response).to redirect_to(admin_salary_structures_path)
    end
  end

  describe "PATCH /admin/salary_structures/:id/toggle_active" do
    it "toggles active status" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant, active: true) }

      patch toggle_active_admin_salary_structure_path(structure), headers: { "Host" => subdomain_host }
      expect(structure.reload.active).to be false

      patch toggle_active_admin_salary_structure_path(structure), headers: { "Host" => subdomain_host }
      expect(structure.reload.active).to be true
    end
  end

  describe "POST /admin/salary_structures/:id/add_component" do
    it "adds a component to the structure" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant) }
      component = ActsAsTenant.with_tenant(tenant) { create(:salary_component, tenant: tenant, name: "Basic") }

      expect {
        post add_component_admin_salary_structure_path(structure),
             params: { salary_structure_component: { salary_component_id: component.id, value: 40 } },
             headers: { "Host" => subdomain_host }
      }.to change { structure.salary_structure_components.count }.by(1)

      expect(response).to redirect_to(admin_salary_structure_path(structure))
    end

    it "rejects duplicate component" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant) }
      component = ActsAsTenant.with_tenant(tenant) { create(:salary_component, tenant: tenant) }
      create(:salary_structure_component, salary_structure: structure, salary_component: component, value: 40)

      expect {
        post add_component_admin_salary_structure_path(structure),
             params: { salary_structure_component: { salary_component_id: component.id, value: 50 } },
             headers: { "Host" => subdomain_host }
      }.not_to change { SalaryStructureComponent.count }

      expect(response).to redirect_to(admin_salary_structure_path(structure))
      expect(flash[:alert]).to be_present
    end

    it "rejects a non-earning (statutory) component" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant) }
      pf = ActsAsTenant.with_tenant(tenant) { create(:salary_component, :deduction, tenant: tenant, name: "PF") }

      expect {
        post add_component_admin_salary_structure_path(structure),
             params: { salary_structure_component: { salary_component_id: pf.id, value: 1800 } },
             headers: { "Host" => subdomain_host }
      }.not_to change { SalaryStructureComponent.count }

      expect(response).to redirect_to(admin_salary_structure_path(structure))
      expect(flash[:alert]).to match(/calculated automatically/i)
    end
  end

  describe "GET /admin/salary_structures/:id picker" do
    it "offers only earning components and shows the statutory note" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant) }
      ActsAsTenant.with_tenant(tenant) do
        create(:salary_component, :earning, tenant: tenant, name: "Special Allowance")
        create(:salary_component, :deduction, tenant: tenant, name: "ProvidentFundDed")
      end

      get admin_salary_structure_path(structure), headers: { "Host" => subdomain_host }

      expect(response.body).to include("Special Allowance")      # earning is offered
      expect(response.body).not_to include("ProvidentFundDed")   # deduction is NOT offered
      expect(response.body).to match(/calculated automatically/i) # info note present
    end
  end

  describe "PATCH /admin/salary_structures/:id/update_component" do
    it "updates a component's value" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant) }
      component = ActsAsTenant.with_tenant(tenant) { create(:salary_component, :percentage, tenant: tenant, name: "Basic") }
      ssc = create(:salary_structure_component, salary_structure: structure, salary_component: component, value: 40)

      patch update_component_admin_salary_structure_path(structure, component_id: ssc.id),
            params: { salary_structure_component: { value: 45 } },
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(admin_salary_structure_path(structure))
      expect(ssc.reload.value).to eq(45)
    end

    it "rejects an invalid (zero/blank) value" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant) }
      component = ActsAsTenant.with_tenant(tenant) { create(:salary_component, tenant: tenant) }
      ssc = create(:salary_structure_component, salary_structure: structure, salary_component: component, value: 1600)

      patch update_component_admin_salary_structure_path(structure, component_id: ssc.id),
            params: { salary_structure_component: { value: "" } },
            headers: { "Host" => subdomain_host }

      expect(ssc.reload.value).to eq(1600)
    end
  end

  describe "DELETE /admin/salary_structures/:id/remove_component" do
    it "removes a component from the structure" do
      structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant) }
      component = ActsAsTenant.with_tenant(tenant) { create(:salary_component, tenant: tenant) }
      ssc = create(:salary_structure_component, salary_structure: structure, salary_component: component, value: 40)

      expect {
        delete remove_component_admin_salary_structure_path(structure, component_id: ssc.id),
               headers: { "Host" => subdomain_host }
      }.to change { structure.salary_structure_components.count }.by(-1)

      expect(response).to redirect_to(admin_salary_structure_path(structure))
    end
  end
end
