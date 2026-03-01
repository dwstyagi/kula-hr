require "rails_helper"

RSpec.describe PayslipLineItem, type: :model do
  let(:tenant)   { create(:tenant) }
  let(:hr_user)  { create(:user, :hr_admin) }
  let(:run)      { create(:payroll_run, tenant: tenant, initiated_by: hr_user) }
  let(:employee) { create(:employee, tenant: tenant) }
  let(:payslip)  { create(:payslip, tenant: tenant, payroll_run: run, employee: employee) }

  before { set_tenant(tenant) }

  subject { build(:payslip_line_item, payslip: payslip) }

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:component_name) }
    it { is_expected.to validate_presence_of(:component_type) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_inclusion_of(:component_type).in_array(PayslipLineItem::COMPONENT_TYPES) }
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe ".earnings scope" do
    it "returns only earning type items" do
      create(:payslip_line_item, payslip: payslip, component_type: "earning")
      create(:payslip_line_item, :deduction, payslip: payslip)
      expect(PayslipLineItem.earnings.count).to eq(1)
    end
  end

  describe ".deductions scope" do
    it "returns only deduction type items" do
      create(:payslip_line_item, payslip: payslip, component_type: "earning")
      create(:payslip_line_item, :deduction, payslip: payslip)
      expect(PayslipLineItem.deductions.count).to eq(1)
    end
  end

  # ── Type helpers ──────────────────────────────────────────────────────────

  describe "#earning?" do
    it "returns true for earning type" do
      expect(build(:payslip_line_item)).to be_earning
    end

    it "returns false for deduction type" do
      expect(build(:payslip_line_item, :deduction)).not_to be_earning
    end
  end

  describe "#deduction?" do
    it "returns true for deduction type" do
      expect(build(:payslip_line_item, :deduction)).to be_deduction
    end

    it "returns false for earning type" do
      expect(build(:payslip_line_item)).not_to be_deduction
    end
  end

  # ── Proration helpers ─────────────────────────────────────────────────────

  describe "#prorated_reduction" do
    it "returns the difference between full_amount and prorated amount" do
      item = build(:payslip_line_item, amount: 30_000, full_amount: 33_333)
      expect(item.prorated_reduction).to eq(3_333)
    end

    it "returns 0 when full_amount is nil (deductions have no full_amount)" do
      item = build(:payslip_line_item, :deduction)
      expect(item.prorated_reduction).to eq(0)
    end

    it "returns 0 when amount equals full_amount (no LOP)" do
      item = build(:payslip_line_item, amount: 33_333, full_amount: 33_333)
      expect(item.prorated_reduction).to eq(0)
    end
  end
end
