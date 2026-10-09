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
    subject { described_class.new(admin, pending_payslip) }   # processed run — still editable

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
    subject { described_class.new(hr_user, pending_payslip) }

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

  # ── Editing window ───────────────────────────────────────────────────────

  describe "editing by run state" do
    def payslip_in(state, month)
      run = create(:payroll_run, state, tenant: tenant, initiated_by: hr_user, month: month, year: 2025)
      create(:payslip, tenant: tenant, payroll_run: run, employee: employee, month: month, year: 2025)
    end

    it "allows edits on a rejected run" do
      expect(described_class.new(hr_user, payslip_in(:rejected, 3))).to be_edit
    end

    it "blocks edits while the run is under review" do
      expect(described_class.new(hr_user, payslip_in(:under_review, 4))).not_to be_edit
    end

    it "blocks edits once the run is approved, even before payslips are locked" do
      expect(described_class.new(hr_user, own_payslip)).not_to be_edit
    end
  end

  describe "Scope for unusual users" do
    before { own_payslip; other_payslip }

    it "returns nothing for a user with no role" do
      roleless = create(:user)
      roleless.roles.clear
      expect(described_class::Scope.new(roleless, Payslip.all).resolve).to be_empty
    end

    it "returns everything in the admin panel for an HR admin who is also an employee" do
      hr_user.add_role(:employee)
      create(:employee, tenant: tenant, user: hr_user)
      expect(described_class::Scope.new(hr_user, Payslip.all).resolve.count).to eq(2)
    end
  end
end
