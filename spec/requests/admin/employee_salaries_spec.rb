require "rails_helper"

RSpec.describe "Admin::Employee Salary Assignment", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user)   { create(:user, :super_admin) }

  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }

  let(:employee) { ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) } }
  let(:structure) { ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant, name: "Standard CTC") } }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: user)
    end
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /admin/employees/:id/assign_salary" do
    it "returns 200" do
      get assign_salary_admin_employee_path(employee), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Assign Salary")
    end
  end

  describe "POST /admin/employees/:id/assign_salary" do
    context "with valid params" do
      it "creates an employee salary and redirects" do
        expect {
          post assign_salary_admin_employee_path(employee),
               params: { employee_salary: { salary_structure_id: structure.id, annual_ctc: 1_200_000, effective_from: Date.today } },
               headers: { "Host" => subdomain_host }
        }.to change { EmployeeSalary.count }.by(1)

        expect(response).to redirect_to(admin_employee_path(employee, anchor: "salary"))
        expect(flash[:notice]).to eq("Salary assigned successfully.")
      end
    end

    context "with invalid params" do
      it "re-renders the form" do
        post assign_salary_admin_employee_path(employee),
             params: { employee_salary: { salary_structure_id: structure.id, annual_ctc: "", effective_from: Date.today } },
             headers: { "Host" => subdomain_host }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /admin/employees/:id/revise_salary" do
    context "when employee has a current salary" do
      before do
        create(:employee_salary,
          tenant: tenant, employee: employee, salary_structure: structure,
          annual_ctc: 600_000, effective_from: 6.months.ago.to_date
        )
      end

      it "returns 200" do
        get revise_salary_admin_employee_path(employee), headers: { "Host" => subdomain_host }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Revise Salary")
      end
    end

    context "when employee has no current salary" do
      it "redirects to assign salary" do
        get revise_salary_admin_employee_path(employee), headers: { "Host" => subdomain_host }
        expect(response).to redirect_to(assign_salary_admin_employee_path(employee))
      end
    end
  end

  describe "POST /admin/employees/:id/revise_salary" do
    let!(:current_salary) do
      create(:employee_salary,
        tenant: tenant, employee: employee, salary_structure: structure,
        annual_ctc: 600_000, effective_from: 6.months.ago.to_date
      )
    end

    context "with valid params" do
      it "closes old salary and creates new one" do
        new_structure = ActsAsTenant.with_tenant(tenant) { create(:salary_structure, tenant: tenant, name: "Senior Package") }

        expect {
          post revise_salary_admin_employee_path(employee),
               params: { employee_salary: { salary_structure_id: new_structure.id, annual_ctc: 900_000, effective_from: Date.today } },
               headers: { "Host" => subdomain_host }
        }.to change { EmployeeSalary.count }.by(1)

        expect(response).to redirect_to(admin_employee_path(employee, anchor: "salary"))

        # Old salary should now have effective_to set
        current_salary.reload
        expect(current_salary.effective_to).to eq(Date.today - 1.day)

        # New salary should be current
        new_salary = employee.employee_salaries.current.first
        expect(new_salary.annual_ctc).to eq(900_000)
        expect(new_salary.salary_structure).to eq(new_structure)
      end
    end

    context "when no current salary exists" do
      it "redirects with alert" do
        current_salary.update!(effective_to: Date.yesterday) # make it not current

        post revise_salary_admin_employee_path(employee),
             params: { employee_salary: { salary_structure_id: structure.id, annual_ctc: 900_000, effective_from: Date.today } },
             headers: { "Host" => subdomain_host }
        expect(response).to redirect_to(admin_employee_path(employee))
      end
    end
  end

  describe "GET /admin/salary_breakup" do
    it "returns JSON breakup for valid params" do
      # Create structure with components
      ActsAsTenant.with_tenant(tenant) do
        basic = create(:salary_component, tenant: tenant, name: "Basic", component_type: "earning", calculation_type: "percentage", sort_order: 1)
        create(:salary_structure_component, salary_structure: structure, salary_component: basic, value: 40)
        create(:payroll_setting, tenant: tenant)
      end

      get admin_salary_breakup_path,
          params: { salary_structure_id: structure.id, annual_ctc: 1_200_000 },
          headers: { "Host" => subdomain_host, "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["earnings"]).to be_an(Array)
      expect(json["net_monthly"]).to be_present
    end

    it "returns error for missing params" do
      get admin_salary_breakup_path,
          params: { salary_structure_id: "", annual_ctc: "" },
          headers: { "Host" => subdomain_host, "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
