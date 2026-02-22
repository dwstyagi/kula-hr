require "rails_helper"

RSpec.describe "Admin::AttendanceSummaries", type: :request do
  let(:tenant)          { create(:tenant, :active) }
  let(:user)            { create(:user, :super_admin) }
  let(:employee)        { create(:employee, tenant: tenant) }
  let(:payroll_setting) { create(:payroll_setting, tenant: tenant) }
  let(:subdomain_host)  { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: user) }
    set_tenant(tenant)
    payroll_setting
    employee   # force creation so generate finds at least one active employee
    sign_in_as(user)
  end

  describe "GET /admin/attendance_summaries" do
    it "returns 200" do
      get admin_attendance_summaries_path(month: 2, year: 2026),
          headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end

    it "shows existing summaries for the selected month" do
      ActsAsTenant.with_tenant(tenant) do
        create(:attendance_summary, tenant: tenant, employee: employee, month: 2, year: 2026)
      end
      get admin_attendance_summaries_path(month: 2, year: 2026),
          headers: { "Host" => subdomain_host }
      expect(response.body).to include(employee.full_name)
    end
  end

  describe "POST /admin/attendance_summaries/generate" do
    it "creates summaries for active employees and redirects" do
      expect {
        post generate_admin_attendance_summaries_path(month: 1, year: 2025),
             headers: { "Host" => subdomain_host }
      }.to change { AttendanceSummary.count }.by(1)

      expect(response).to redirect_to(admin_attendance_summaries_path(month: 1, year: 2025))
      expect(flash[:notice]).to include("generated")
    end
  end

  describe "GET /admin/attendance_summaries/:id/edit (Turbo Frame)" do
    let!(:summary) do
      ActsAsTenant.with_tenant(tenant) do
        create(:attendance_summary, tenant: tenant, employee: employee, month: 2, year: 2026)
      end
    end

    it "returns 200 with the edit form" do
      get edit_admin_attendance_summary_path(summary),
          headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/attendance_summaries/:id" do
    let!(:summary) do
      ActsAsTenant.with_tenant(tenant) do
        create(:attendance_summary, tenant: tenant, employee: employee,
               month: 2, year: 2026, total_working_days: 20, days_present: 20)
      end
    end

    it "updates days_present and recalculates derived fields" do
      patch admin_attendance_summary_path(summary),
            params: { attendance_summary: { days_present: 18, half_days: 0 } },
            headers: { "Host" => subdomain_host }

      expect(response).to have_http_status(:ok)
      expect(summary.reload.days_present).to eq(18)
      expect(summary.reload.unapproved_absences).to eq(2)
      expect(summary.reload.lop_days).to eq(2)
    end

    it "does not update a locked summary" do
      locked = ActsAsTenant.with_tenant(tenant) do
        create(:attendance_summary, :locked, tenant: tenant, employee: employee,
               month: 3, year: 2026)
      end

      patch admin_attendance_summary_path(locked),
            params: { attendance_summary: { days_present: 10 } },
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(root_path)   # Pundit not authorized redirect
    end
  end

  describe "PATCH /admin/attendance_summaries/lock_month" do
    before do
      ActsAsTenant.with_tenant(tenant) do
        create(:attendance_summary, tenant: tenant, employee: employee, month: 1, year: 2025)
      end
    end

    it "locks all draft summaries for the month" do
      patch lock_month_admin_attendance_summaries_path(month: 1, year: 2025),
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(admin_attendance_summaries_path(month: 1, year: 2025))
      expect(AttendanceSummary.where(month: 1, year: 2025).all?(&:locked?)).to be true
    end
  end

  describe "GET /admin/attendance_summaries/download_template" do
    before do
      ActsAsTenant.with_tenant(tenant) do
        create(:attendance_summary, tenant: tenant, employee: employee, month: 1, year: 2025)
      end
    end

    it "returns a CSV file" do
      get download_template_admin_attendance_summaries_path(month: 1, year: 2025),
          headers: { "Host" => subdomain_host }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("employee_code")
      expect(response.body).to include(employee.employee_code)
    end
  end
end
