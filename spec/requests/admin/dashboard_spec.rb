require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:user)   { create(:user, :super_admin) }
  let(:host)   { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: user) }
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /admin (setup checklist)" do
    it "shows the checklist pre-filled at 2 of 6 for a brand-new tenant" do
      get admin_root_path, headers: { "Host" => host }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Get set up")
      expect(response.body).to include("2 / 6")
      expect(response.body).to include("Add your employees")
    end

    it "advances as employees, salaries, and locked attendance are added" do
      ActsAsTenant.with_tenant(tenant) do
        employee = create(:employee, tenant: tenant)
        create(:employee_salary, tenant: tenant, employee: employee)
        create(:attendance_summary, :locked, tenant: tenant, employee: employee)
      end

      get admin_root_path, headers: { "Host" => host }

      expect(response.body).to include("5 / 6")
    end

    it "disappears once the tenant has an approved or paid payroll run" do
      ActsAsTenant.with_tenant(tenant) { create(:payroll_run, :approved, tenant: tenant) }

      get admin_root_path, headers: { "Host" => host }

      expect(response.body).not_to include("Get set up")
    end
  end

  describe "GET /admin (needs-attention leave aging)" do
    it "frames the pending leave count with how long the oldest request has waited" do
      ActsAsTenant.with_tenant(tenant) do
        employee = create(:employee, tenant: tenant)
        leave_type = create(:leave_type, tenant: tenant)
        leave_request = LeaveRequest.new(
          tenant: tenant, employee: employee, leave_type: leave_type,
          from_date: Date.today + 10, to_date: Date.today + 12,
          number_of_days: 3, reason: "Vacation", status: :pending
        )
        leave_request.save(validate: false)
        leave_request.update_column(:created_at, 6.days.ago)
      end

      get admin_root_path, headers: { "Host" => host }

      expect(response.body).to include("oldest 6 days")
    end
  end
end
