require "rails_helper"

RSpec.describe PayslipPolicy, type: :policy do
  let(:tenant)   { create(:tenant) }
  let(:admin)    { create(:user, :super_admin) }
  let(:hr_user)  { create(:user, :hr_admin) }
  let(:emp_user) { create(:user, :employee) }
  let(:other_emp_user) { create(:user, :employee) }

  let(:employee)       { create(:employee, tenant: tenant, user: emp_user) }
  let(:other_employee) { create(:employee, tenant: tenant, user: other_emp_user) }

  let(:approved_run) { create(:payroll_run, :approved, tenant: tenant, initiated_by: hr_user, month: 1, year: 2026) }
  let(:pending_run)  { create(:payroll_run, :processed, tenant: tenant, initiated_by: hr_user, month: 2, year: 2026) }

  let(:own_payslip)       { create(:payslip, tenant: tenant, payroll_run: approved_run, employee: employee) }
  let(:other_payslip)     { create(:payslip, tenant: tenant, payroll_run: approved_run, employee: other_employee) }
  let(:pending_payslip)   { create(:payslip, tenant: tenant, payroll_run: pending_run,  employee: employee) }
  let(:locked_payslip)    { create(:payslip, :locked, tenant: tenant, payroll_run: approved_run, employee: other_employee) }

  before { set_tenant(tenant) }

  # ── Super Admin ───────────────────────────────────────────────────────────

  describe "for a super_admin" do
    subject { described_class.new(admin, own_payslip) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_edit }
    it { is_expected.to be_update }
  end

  describe "super_admin on a locked payslip" do
    subject { described_class.new(admin, locked_payslip) }

    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_update }
  end

  # ── HR Admin ──────────────────────────────────────────────────────────────

  describe "for an hr_admin (generated payslip)" do
    subject { described_class.new(hr_user, own_payslip) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_edit }
    it { is_expected.to be_update }
  end

  describe "for an hr_admin (locked payslip)" do
    subject { described_class.new(hr_user, locked_payslip) }

    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_update }
  end

  # ── Employee — own payslip from approved run ──────────────────────────────

  describe "for an employee viewing their own payslip (approved run)" do
    subject { described_class.new(emp_user, own_payslip) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_update }
  end

  # ── Employee — another employee's payslip ────────────────────────────────

  describe "for an employee viewing someone else's payslip" do
    subject { described_class.new(emp_user, other_payslip) }

    it { is_expected.not_to be_show }
  end

  # ── Employee — payslip from non-approved run ──────────────────────────────

  describe "for an employee viewing payslip from a processed (non-approved) run" do
    subject { described_class.new(emp_user, pending_payslip) }

    it { is_expected.not_to be_show }
  end

  # ── Scope ─────────────────────────────────────────────────────────────────

  describe "Scope" do
    before do
      # Ensure records are created
      own_payslip
      other_payslip
      pending_payslip
    end

    it "returns all payslips for admin" do
      scope = described_class::Scope.new(admin, Payslip.all).resolve
      expect(scope.count).to eq(3)
    end

    it "returns only own payslips from approved/paid runs for employee" do
      scope = described_class::Scope.new(emp_user, Payslip.all).resolve
      expect(scope).to include(own_payslip)
      expect(scope).not_to include(other_payslip)
      expect(scope).not_to include(pending_payslip)
    end

    it "returns scope.none when employee has no Employee record" do
      user_without_employee = create(:user, :employee)
      scope = described_class::Scope.new(user_without_employee, Payslip.all).resolve
      expect(scope.count).to eq(0)
    end
  end
end
