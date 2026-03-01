require "rails_helper"

RSpec.describe "Admin::Payslips", type: :request do
  let(:tenant)   { create(:tenant, :active) }
  let(:hr_user)  { create(:user, :hr_admin) }
  let(:admin)    { create(:user, :super_admin) }
  let(:host)     { "#{tenant.subdomain}.lvh.me" }

  let(:run) do
    ActsAsTenant.with_tenant(tenant) do
      create(:payroll_run, :processed, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
    end
  end

  let(:employee) do
    ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) }
  end

  let(:payslip) do
    ActsAsTenant.with_tenant(tenant) do
      create(:payslip, tenant: tenant, payroll_run: run, employee: employee,
             gross_pay: 50_000, total_deductions: 5_000, net_pay: 45_000)
    end
  end

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: hr_user)
      create(:tenant_user, tenant: tenant, user: admin)
    end
    set_tenant(tenant)
    sign_in_as(hr_user)
  end

  def headers = { "Host" => host }

  # ── Index ─────────────────────────────────────────────────────────────────

  describe "GET /admin/payroll_runs/:payroll_run_id/payslips" do
    it "returns 200 and lists payslips" do
      payslip  # ensure created
      get admin_payroll_run_payslips_path(run), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employee.full_name)
    end

    it "filters by query param" do
      payslip
      other_emp = ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant, first_name: "Zyx", last_name: "Abc") }
      ActsAsTenant.with_tenant(tenant) do
        create(:payslip, tenant: tenant, payroll_run: run, employee: other_emp)
      end

      get admin_payroll_run_payslips_path(run, q: employee.first_name), headers: headers
      expect(response.body).to include(employee.full_name)
      expect(response.body).not_to include("ZYX ABC")
    end
  end

  # ── Show ──────────────────────────────────────────────────────────────────

  describe "GET /admin/payslips/:id" do
    it "returns 200 and shows payslip detail" do
      get admin_payslip_path(payslip), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(employee.full_name)
    end
  end

  # ── Edit ──────────────────────────────────────────────────────────────────

  describe "GET /admin/payslips/:id/edit" do
    it "returns 200 for an unlocked payslip" do
      get edit_admin_payslip_path(payslip), headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "redirects with not-authorized flash for a locked payslip" do
      locked = ActsAsTenant.with_tenant(tenant) do
        create(:payslip, :locked, tenant: tenant, payroll_run: run, employee: employee)
      end
      get edit_admin_payslip_path(locked), headers: headers
      expect(response).to be_redirect
    end
  end

  # ── Update ────────────────────────────────────────────────────────────────

  describe "PATCH /admin/payslips/:id" do
    let!(:line_item) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payslip_line_item, payslip: payslip, component_name: "Basic",
               component_type: "earning", amount: 30_000, sort_order: 1)
      end
    end

    it "updates a line item amount and recalculates totals" do
      patch admin_payslip_path(payslip),
            params: { line_items: { line_item.id.to_s => { amount: "32000" } } },
            headers: headers

      expect(response).to redirect_to(admin_payslip_path(payslip))
      expect(line_item.reload.amount).to eq(32_000)
      expect(payslip.reload.gross_pay).to eq(32_000)
      expect(payslip.reload.status).to eq("revised")
    end

    it "adds a new line item" do
      expect {
        patch admin_payslip_path(payslip),
              params: {
                new_line_items: {
                  "0" => { component_name: "Bonus", component_type: "earning", amount: "5000" }
                }
              },
              headers: headers
      }.to change { payslip.line_items.count }.by(1)
    end

    it "removes a line item" do
      line_item  # ensure created
      expect {
        patch admin_payslip_path(payslip),
              params: { remove_line_items: [ line_item.id ] },
              headers: headers
      }.to change { payslip.line_items.count }.by(-1)
    end

    it "marks payslip as revised after update" do
      patch admin_payslip_path(payslip),
            params: { line_items: { line_item.id.to_s => { amount: "31000" } } },
            headers: headers
      expect(payslip.reload.is_revised).to be true
    end

    it "redirects with not-authorized flash for locked payslips" do
      locked = ActsAsTenant.with_tenant(tenant) do
        other_emp = create(:employee, tenant: tenant)
        create(:payslip, :locked, tenant: tenant, payroll_run: run, employee: other_emp)
      end
      patch admin_payslip_path(locked),
            params: { line_items: {} },
            headers: headers
      expect(response).to be_redirect
      expect(locked.reload.status).to eq("locked")  # unchanged
    end
  end
end
