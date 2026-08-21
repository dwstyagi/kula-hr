require "rails_helper"

RSpec.describe PayrollRunPolicy, type: :policy do
  let(:tenant)    { create(:tenant) }
  let(:admin)     { create(:user, :super_admin) }
  let(:hr_user)   { create(:user, :hr_admin) }
  let(:emp_user)  { create(:user, :employee) }

  let(:run) { create(:payroll_run, tenant: tenant, initiated_by: hr_user) }

  before { set_tenant(tenant) }

  # ── Super Admin ───────────────────────────────────────────────────────────

  describe "for a super_admin" do
    subject { described_class.new(admin, run) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_new }
    it { is_expected.to be_create }
    it { is_expected.to be_process_payroll }
    it { is_expected.to be_submit_for_review }
    it { is_expected.to be_resubmit_for_review }
    it { is_expected.to be_reprocess }
    it { is_expected.to be_mark_paid }
    it { is_expected.to be_progress }
    it { is_expected.to be_download_bank_file }
    it { is_expected.to be_approve }
    it { is_expected.to be_reject }
  end

  # ── Off-cycle maker-checker ───────────────────────────────────────────────

  describe "for an off-cycle run" do
    let(:other_admin) { create(:user, :super_admin) }
    let(:off_cycle_run) do
      create(:payroll_run, tenant: tenant, initiated_by: admin,
             run_type: "bonus", title: "Diwali Bonus", payment_date: Date.current)
    end

    it "blocks the super admin who raised it from approving" do
      expect(described_class.new(admin, off_cycle_run)).not_to be_approve
    end

    it "lets a different super admin approve" do
      expect(described_class.new(other_admin, off_cycle_run)).to be_approve
    end

    it "still lets the initiator reject, so the run is never stranded" do
      expect(described_class.new(admin, off_cycle_run)).to be_reject
    end

    it "keeps rejection off-limits for hr_admin" do
      expect(described_class.new(hr_user, off_cycle_run)).not_to be_reject
    end
  end

  # ── HR Admin ──────────────────────────────────────────────────────────────

  describe "for an hr_admin" do
    subject { described_class.new(hr_user, run) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_new }
    it { is_expected.to be_create }
    it { is_expected.to be_process_payroll }
    it { is_expected.to be_submit_for_review }
    it { is_expected.to be_resubmit_for_review }
    it { is_expected.to be_reprocess }
    it { is_expected.to be_mark_paid }
    it { is_expected.to be_progress }
    it { is_expected.to be_download_bank_file }

    it { is_expected.not_to be_approve }
    it { is_expected.not_to be_reject }
  end

  # ── Employee ──────────────────────────────────────────────────────────────

  describe "for an employee" do
    subject { described_class.new(emp_user, run) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_approve }
    it { is_expected.not_to be_reject }
    it { is_expected.not_to be_process_payroll }
  end

  # ── Scope ─────────────────────────────────────────────────────────────────

  describe "Scope" do
    it "returns all runs for an admin" do
      create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
      create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 2, year: 2026)

      scope = described_class::Scope.new(admin, PayrollRun.all).resolve
      expect(scope.count).to eq(2)
    end

    it "returns all runs for an hr_admin" do
      create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)

      scope = described_class::Scope.new(hr_user, PayrollRun.all).resolve
      expect(scope.count).to eq(1)
    end
  end
end
