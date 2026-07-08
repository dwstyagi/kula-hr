require "rails_helper"

RSpec.describe "Admin::LeaveRequests", type: :request do
  let(:tenant)    { create(:tenant, :active) }
  let(:user)      { create(:user, :super_admin) }
  let(:employee)  { create(:employee, tenant: tenant) }
  let(:leave_type) { create(:leave_type, :casual, tenant: tenant) }
  let(:balance) do
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type,
           total_days: 12, used_days: 0, remaining_days: 12)
  end
  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: user) }
    set_tenant(tenant)
    sign_in_as(user)
  end

  describe "GET /admin/leave_requests" do
    it "returns 200 and lists leave requests" do
      ActsAsTenant.with_tenant(tenant) do
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type)
        lr.save(validate: false)
      end

      get admin_leave_requests_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  let(:future_monday) { Date.today.next_occurring(:monday) + 14 }

  describe "PATCH /admin/leave_requests/:id/approve" do
    let!(:leave_request) do
      ActsAsTenant.with_tenant(tenant) do
        balance
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: future_monday, to_date: future_monday)
        lr.save(validate: false)
        lr
      end
    end

    it "approves the request and deducts balance" do
      patch approve_admin_leave_request_path(leave_request),
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(admin_leave_requests_path)
      expect(leave_request.reload).to be_approved
      expect(balance.reload.remaining_days).to eq(11)
    end

    context "when employee's leave approver is a reporting_manager who can log in" do
      let(:manager) { create(:employee, :with_user, tenant: tenant, email: "mgr@x.com") }

      before do
        ActsAsTenant.with_tenant(tenant) do
          employee.update!(leave_approver: :reporting_manager, reporting_manager: manager)
        end
      end

      it "blocks HR from approving and redirects with alert" do
        patch approve_admin_leave_request_path(leave_request),
              headers: { "Host" => subdomain_host }

        expect(response).to redirect_to(admin_leave_requests_path)
        expect(leave_request.reload).to be_pending
      end
    end

    context "when the reporting-manager approver has no login account" do
      let(:manager) { create(:employee, tenant: tenant, email: "mgr@x.com") }

      before do
        ActsAsTenant.with_tenant(tenant) do
          employee.update!(leave_approver: :reporting_manager, reporting_manager: manager)
        end
      end

      it "lets HR approve as the catch-all fallback (no deadlock)" do
        patch approve_admin_leave_request_path(leave_request),
              headers: { "Host" => subdomain_host }

        expect(leave_request.reload).to be_approved
      end
    end
  end

  describe "PATCH /admin/leave_requests/:id/reject" do
    let!(:leave_request) do
      ActsAsTenant.with_tenant(tenant) do
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: future_monday, to_date: future_monday)
        lr.save(validate: false)
        lr
      end
    end

    it "rejects the request with a reason" do
      patch reject_admin_leave_request_path(leave_request),
            params: { rejection_reason: "Insufficient notice" },
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(admin_leave_requests_path)
      expect(leave_request.reload).to be_rejected
      expect(leave_request.reload.rejection_reason).to eq("Insufficient notice")
    end
  end

  describe "PATCH /admin/leave_requests/:id/cancel" do
    let!(:approved_request) do
      ActsAsTenant.with_tenant(tenant) do
        balance.update!(used_days: 1, remaining_days: 11)
        lr = build(:leave_request, :approved, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: future_monday, to_date: future_monday)
        lr.save(validate: false)
        lr
      end
    end

    it "cancels the request and credits balance" do
      patch cancel_admin_leave_request_path(approved_request),
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(admin_leave_requests_path)
      expect(approved_request.reload).to be_cancelled
      expect(balance.reload.remaining_days).to eq(12)
    end
  end

  describe "GET /admin/leave_requests/:id" do
    let!(:leave_request) do
      ActsAsTenant.with_tenant(tenant) do
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: future_monday, to_date: future_monday)
        lr.save(validate: false)
        lr
      end
    end

    it "renders the detail drawer" do
      get admin_leave_request_path(leave_request), headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employee.full_name)
    end
  end

  describe "PATCH /admin/leave_requests/bulk_approve" do
    let!(:leave_request) do
      ActsAsTenant.with_tenant(tenant) do
        balance
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: future_monday, to_date: future_monday)
        lr.save(validate: false)
        lr
      end
    end

    it "approves all selected pending requests" do
      patch bulk_approve_admin_leave_requests_path, params: { ids: [ leave_request.id ] },
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(admin_leave_requests_path)
      expect(leave_request.reload).to be_approved
      expect(balance.reload.remaining_days).to eq(11)
    end

    it "skips requests whose approver is the reporting manager" do
      manager = create(:employee, :with_user, tenant: tenant, email: "bulkmgr@x.com")
      ActsAsTenant.with_tenant(tenant) do
        employee.update!(leave_approver: :reporting_manager, reporting_manager: manager)
      end

      patch bulk_approve_admin_leave_requests_path, params: { ids: [ leave_request.id ] },
            headers: { "Host" => subdomain_host }

      expect(leave_request.reload).to be_pending
      expect(flash[:alert]).to include("manager approves")
    end
  end
end
