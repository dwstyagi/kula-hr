require "rails_helper"

RSpec.describe "EmployeePortal::TeamLeaveRequests", type: :request do
  let(:tenant)       { create(:tenant, :active) }
  let(:mgr_user)     { create(:user, :employee) }
  let(:manager)      { create(:employee, tenant: tenant, user: mgr_user, email: "mgr@x.com") }
  let(:emp_user)     { create(:user, :employee) }
  let(:employee)     { create(:employee, tenant: tenant, user: emp_user, reporting_manager: manager) }
  let(:leave_type)   { create(:leave_type, :casual, tenant: tenant) }
  let(:balance) do
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type,
           total_days: 12, used_days: 0, remaining_days: 12)
  end
  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }
  let(:future_monday)  { Date.today.next_occurring(:monday) + 14 }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: mgr_user)
      create(:tenant_user, tenant: tenant, user: emp_user)
      employee
      balance
    end
    set_tenant(tenant)
    sign_in_as(mgr_user)
  end

  let!(:leave_request) do
    ActsAsTenant.with_tenant(tenant) do
      lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                 from_date: future_monday, to_date: future_monday)
      lr.save(validate: false)
      lr
    end
  end

  describe "GET /portal/team_leave_requests" do
    it "returns 200 for a manager with direct reports" do
      get employee_portal_team_leave_requests_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /portal/team_leave_requests/:id/approve" do
    context "when employee's leave_approver is reporting_manager" do
      before do
        ActsAsTenant.with_tenant(tenant) { employee.update!(leave_approver: :reporting_manager) }
      end

      it "approves the request and deducts balance" do
        patch approve_employee_portal_team_leave_request_path(leave_request),
              headers: { "Host" => subdomain_host }

        expect(response).to redirect_to(employee_portal_team_leave_requests_path)
        expect(leave_request.reload).to be_approved
        expect(balance.reload.remaining_days).to eq(11)
      end
    end

    context "when employee's leave_approver is hr" do
      before do
        ActsAsTenant.with_tenant(tenant) { employee.update!(leave_approver: :hr) }
      end

      it "blocks the manager and keeps request pending" do
        patch approve_employee_portal_team_leave_request_path(leave_request),
              headers: { "Host" => subdomain_host }

        expect(response).to redirect_to(employee_portal_team_leave_requests_path)
        expect(leave_request.reload).to be_pending
      end
    end
  end

  describe "PATCH /portal/team_leave_requests/:id/reject" do
    context "when employee's leave_approver is reporting_manager" do
      before do
        ActsAsTenant.with_tenant(tenant) { employee.update!(leave_approver: :reporting_manager) }
      end

      it "rejects the request" do
        patch reject_employee_portal_team_leave_request_path(leave_request),
              params: { rejection_reason: "Team at full capacity" },
              headers: { "Host" => subdomain_host }

        expect(response).to redirect_to(employee_portal_team_leave_requests_path)
        expect(leave_request.reload).to be_rejected
        expect(leave_request.reload.rejection_reason).to eq("Team at full capacity")
      end
    end

    context "when employee's leave_approver is hr" do
      before do
        ActsAsTenant.with_tenant(tenant) { employee.update!(leave_approver: :hr) }
      end

      it "blocks the manager and keeps request pending" do
        patch reject_employee_portal_team_leave_request_path(leave_request),
              params: { rejection_reason: "Not allowed" },
              headers: { "Host" => subdomain_host }

        expect(response).to redirect_to(employee_portal_team_leave_requests_path)
        expect(leave_request.reload).to be_pending
      end
    end
  end
end
