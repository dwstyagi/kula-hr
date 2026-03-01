require "rails_helper"

RSpec.describe "Admin::PayrollRuns", type: :request do
  let(:tenant)   { create(:tenant, :active) }
  let(:hr_user)  { create(:user, :hr_admin) }
  let(:admin)    { create(:user, :super_admin) }
  let(:host)     { "#{tenant.subdomain}.lvh.me" }

  before do
    ActsAsTenant.with_tenant(tenant) do
      create(:tenant_user, tenant: tenant, user: hr_user)
      create(:tenant_user, tenant: tenant, user: admin)
    end
    set_tenant(tenant)
  end

  def headers = { "Host" => host }
  def sign_in(user) = sign_in_as(user)

  # ── Index ─────────────────────────────────────────────────────────────────

  describe "GET /admin/payroll_runs" do
    before { sign_in(hr_user) }

    it "returns 200" do
      get admin_payroll_runs_path, headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "lists existing payroll runs" do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :processed, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
      get admin_payroll_runs_path, headers: headers
      expect(response.body).to include("January 2026")
    end
  end

  # ── New ───────────────────────────────────────────────────────────────────

  describe "GET /admin/payroll_runs/new" do
    before { sign_in(hr_user) }

    it "returns 200" do
      get new_admin_payroll_run_path, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  # ── Create ────────────────────────────────────────────────────────────────

  describe "POST /admin/payroll_runs" do
    before { sign_in(hr_user) }

    context "with no employees (attendance validation passes)" do
      it "creates a payroll run and redirects" do
        expect {
          post admin_payroll_runs_path,
               params: { payroll_run: { month: 1, year: 2026 } },
               headers: headers
        }.to change { PayrollRun.count }.by(1)

        expect(response).to redirect_to(admin_payroll_run_path(PayrollRun.last))
      end
    end

    context "when attendance is not locked" do
      before do
        ActsAsTenant.with_tenant(tenant) do
          create(:employee, tenant: tenant, employment_status: "active")
          # No locked attendance summary
        end
      end

      it "re-renders new with 422" do
        post admin_payroll_runs_path,
             params: { payroll_run: { month: 1, year: 2026 } },
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── Show ──────────────────────────────────────────────────────────────────

  describe "GET /admin/payroll_runs/:id" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :processed, tenant: tenant, initiated_by: hr_user, month: 2, year: 2026)
      end
    end

    before { sign_in(hr_user) }

    it "returns 200 and shows the run" do
      get admin_payroll_run_path(run), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("February 2026")
    end
  end

  # ── Process Payroll ───────────────────────────────────────────────────────

  describe "POST /admin/payroll_runs/:id/process_payroll" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    before { sign_in(hr_user) }

    it "enqueues a PayrollProcessingJob and redirects" do
      expect(PayrollProcessingJob).to receive(:perform_later).with(run.id)
      post process_payroll_admin_payroll_run_path(run), headers: headers
      expect(response).to redirect_to(admin_payroll_run_path(run))
    end

    it "does not process a run already in processing state" do
      run.update_column(:status, "processing")
      expect(PayrollProcessingJob).not_to receive(:perform_later)
      post process_payroll_admin_payroll_run_path(run), headers: headers
      expect(response).to redirect_to(admin_payroll_run_path(run))
    end
  end

  # ── Submit for Review ─────────────────────────────────────────────────────

  describe "PATCH /admin/payroll_runs/:id/submit_for_review" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :processed, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    before { sign_in(hr_user) }

    it "transitions to under_review and redirects" do
      patch submit_for_review_admin_payroll_run_path(run), headers: headers
      expect(run.reload.status).to eq("under_review")
      expect(response).to redirect_to(admin_payroll_run_path(run))
    end

    it "sends the submitted_for_review email" do
      expect(PayrollMailer).to receive_message_chain(:submitted_for_review, :deliver_later)
      patch submit_for_review_admin_payroll_run_path(run), headers: headers
    end
  end

  # ── Approve ───────────────────────────────────────────────────────────────

  describe "PATCH /admin/payroll_runs/:id/approve" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :under_review, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    context "as super_admin" do
      before { sign_in(admin) }

      it "transitions to approved and locks payslips" do
        emp = ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) }
        ActsAsTenant.with_tenant(tenant) do
          create(:payslip, tenant: tenant, payroll_run: run, employee: emp, status: "generated")
        end

        patch approve_admin_payroll_run_path(run), headers: headers
        expect(run.reload.status).to eq("approved")
        expect(run.payslips.pluck(:status)).to all(eq("locked"))
        expect(response).to redirect_to(admin_payroll_run_path(run))
      end
    end

    context "as hr_admin" do
      before { sign_in(hr_user) }

      it "redirects with not-authorized flash (Pundit rescues and redirects)" do
        patch approve_admin_payroll_run_path(run), headers: headers
        expect(response).to be_redirect
        expect(run.reload.status).to eq("under_review")  # unchanged
      end
    end
  end

  # ── Reject ────────────────────────────────────────────────────────────────

  describe "PATCH /admin/payroll_runs/:id/reject" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :under_review, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    before { sign_in(admin) }

    it "transitions to rejected with a reason" do
      patch reject_admin_payroll_run_path(run),
            params: { rejection_reason: "Salary figures are wrong." },
            headers: headers
      expect(run.reload.status).to eq("rejected")
      expect(run.reload.rejection_reason).to eq("Salary figures are wrong.")
    end

    it "sends the rejected email" do
      expect(PayrollMailer).to receive_message_chain(:rejected, :deliver_later)
      patch reject_admin_payroll_run_path(run),
            params: { rejection_reason: "Incorrect data." },
            headers: headers
    end
  end

  # ── Resubmit for Review ───────────────────────────────────────────────────

  describe "PATCH /admin/payroll_runs/:id/resubmit_for_review" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :rejected, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    before { sign_in(hr_user) }

    it "transitions to under_review without wiping payslips" do
      emp = ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) }
      ActsAsTenant.with_tenant(tenant) do
        create(:payslip, tenant: tenant, payroll_run: run, employee: emp)
      end

      patch resubmit_for_review_admin_payroll_run_path(run), headers: headers
      expect(run.reload.status).to eq("under_review")
      expect(run.payslips.count).to eq(1)
    end
  end

  # ── Reprocess ─────────────────────────────────────────────────────────────

  describe "PATCH /admin/payroll_runs/:id/reprocess" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :processed, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    before { sign_in(hr_user) }

    it "resets to draft and destroys payslips" do
      emp = ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) }
      ActsAsTenant.with_tenant(tenant) do
        create(:payslip, tenant: tenant, payroll_run: run, employee: emp)
      end

      patch reprocess_admin_payroll_run_path(run), headers: headers
      expect(run.reload.status).to eq("draft")
      expect(run.payslips.count).to eq(0)
    end
  end

  # ── Mark Paid ─────────────────────────────────────────────────────────────

  describe "PATCH /admin/payroll_runs/:id/mark_paid" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    before { sign_in(hr_user) }

    it "transitions to paid and redirects" do
      patch mark_paid_admin_payroll_run_path(run), headers: headers
      expect(run.reload.status).to eq("paid")
      expect(response).to redirect_to(admin_payroll_run_path(run))
    end
  end

  # ── Bank File ─────────────────────────────────────────────────────────────

  describe "GET /admin/payroll_runs/:id/bank_file" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    before { sign_in(hr_user) }

    it "returns 200" do
      get bank_file_admin_payroll_run_path(run), headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  # ── Download Bank File ────────────────────────────────────────────────────

  describe "GET /admin/payroll_runs/:id/download_bank_file" do
    let(:run) do
      ActsAsTenant.with_tenant(tenant) do
        create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      end
    end

    before { sign_in(hr_user) }

    it "downloads a CSV file for generic_csv format" do
      get download_bank_file_admin_payroll_run_path(run, bank: "generic_csv"), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
    end

    it "downloads a txt file for hdfc format" do
      get download_bank_file_admin_payroll_run_path(run, bank: "hdfc"), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/plain")
    end
  end
end
