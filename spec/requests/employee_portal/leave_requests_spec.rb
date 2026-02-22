require "rails_helper"

RSpec.describe "EmployeePortal::LeaveRequests", type: :request do
  let(:tenant)     { create(:tenant, :active) }
  let(:emp_user)   { create(:user, :employee) }
  let(:employee)   { create(:employee, tenant: tenant, user: emp_user) }
  let(:leave_type) { create(:leave_type, :casual, tenant: tenant) }
  let(:balance) do
    create(:leave_balance, tenant: tenant, employee: employee, leave_type: leave_type,
           total_days: 12, used_days: 0, remaining_days: 12)
  end
  let(:subdomain_host) { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) { create(:tenant_user, tenant: tenant, user: emp_user) }
    set_tenant(tenant)
    employee   # ensure employee is created before sign-in
    sign_in_as(emp_user)
  end

  describe "GET /portal/leave_requests" do
    it "returns 200 and shows leave balances" do
      ActsAsTenant.with_tenant(tenant) { balance }
      get employee_portal_leave_requests_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /portal/leave_requests/new" do
    it "returns 200 with the apply form" do
      get new_employee_portal_leave_request_path, headers: { "Host" => subdomain_host }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /portal/leave_requests" do
    before { balance }

    let(:future_monday) { Date.today.next_occurring(:monday) + 14 }

    context "with valid params" do
      it "creates a leave request and redirects" do
        expect {
          post employee_portal_leave_requests_path,
               params: {
                 leave_request: {
                   leave_type_id: leave_type.id,
                   from_date:     future_monday,
                   to_date:       future_monday,
                   reason:        "Doctor appointment"
                 }
               },
               headers: { "Host" => subdomain_host }
        }.to change { LeaveRequest.count }.by(1)

        expect(response).to redirect_to(employee_portal_leave_requests_path)
        expect(LeaveRequest.last.employee).to eq(employee)
      end
    end

    context "with invalid params (past date)" do
      it "re-renders new with errors" do
        post employee_portal_leave_requests_path,
             params: {
               leave_request: {
                 leave_type_id: leave_type.id,
                 from_date:     Date.today - 1,
                 to_date:       Date.today - 1,
                 reason:        "Past date"
               }
             },
             headers: { "Host" => subdomain_host }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with insufficient balance" do
      before { balance.update!(remaining_days: 0) }

      it "re-renders with balance error" do
        post employee_portal_leave_requests_path,
             params: {
               leave_request: {
                 leave_type_id: leave_type.id,
                 from_date:     future_monday,
                 to_date:       future_monday + 4,
                 reason:        "Vacation"
               }
             },
             headers: { "Host" => subdomain_host }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  let(:future_monday) { Date.today.next_occurring(:monday) + 14 }

  describe "PATCH /portal/leave_requests/:id/cancel" do
    let!(:pending_request) do
      ActsAsTenant.with_tenant(tenant) do
        lr = build(:leave_request, :pending, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: future_monday, to_date: future_monday)
        lr.save(validate: false)
        lr
      end
    end

    it "cancels a pending request" do
      patch cancel_employee_portal_leave_request_path(pending_request),
            headers: { "Host" => subdomain_host }

      expect(response).to redirect_to(employee_portal_leave_requests_path)
      expect(pending_request.reload).to be_cancelled
    end

    it "cannot cancel an approved request" do
      approved = ActsAsTenant.with_tenant(tenant) do
        lr = build(:leave_request, :approved, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: future_monday, to_date: future_monday)
        lr.save(validate: false)
        lr
      end

      patch cancel_employee_portal_leave_request_path(approved),
            headers: { "Host" => subdomain_host }

      expect(approved.reload).to be_approved
    end
  end
end
