require "rails_helper"

RSpec.describe Statutory::ProfessionalTaxCalculator do
  let(:tenant)   { create(:tenant) }
  let(:employee) { build(:employee, tenant: tenant) }
  let(:setting)  { build(:payroll_setting, tenant: tenant, pt_enabled: true, pt_state: "maharashtra") }

  def calc(gross:, month: 3, emp: employee, s: setting)
    described_class.new(gross: gross, setting: s, employee: emp, month: month).call
  end

  # Helpers to seed Maharashtra slabs for a tenant
  def seed_mh_slabs(tenant)
    create(:professional_tax_slab, :mh_low,  tenant: tenant)
    create(:professional_tax_slab, :mh_mid,  tenant: tenant)
    create(:professional_tax_slab, :mh_high, tenant: tenant)
    create(:professional_tax_slab, :mh_feb,  tenant: tenant)
  end

  def seed_ka_slabs(tenant)
    create(:professional_tax_slab, :ka_low,  tenant: tenant)
    create(:professional_tax_slab, :ka_high, tenant: tenant)
  end

  # ── Maharashtra standard months ───────────────────────────────────────────

  context "Maharashtra — normal month (March)" do
    before { seed_mh_slabs(tenant) }

    it "returns ₹0 for gross below ₹7,500" do
      result = calc(gross: 6_000)
      expect(result.applicable).to be true
      expect(result.amount).to eq(0)
    end

    it "returns ₹175 for gross in ₹7,501–₹10,000 range" do
      result = calc(gross: 8_000)
      expect(result.amount).to eq(175)
    end

    it "returns ₹200 for gross above ₹10,000" do
      result = calc(gross: 81_533)
      expect(result.amount).to eq(200)
    end

    it "records the state on the result" do
      result = calc(gross: 81_533)
      expect(result.state).to eq("maharashtra")
    end
  end

  # ── Maharashtra February special ─────────────────────────────────────────

  context "Maharashtra — February (month = 2)" do
    before { seed_mh_slabs(tenant) }

    it "returns ₹300 for gross above ₹10,000 in February" do
      result = calc(gross: 81_533, month: 2)
      expect(result.amount).to eq(300)
    end

    it "returns ₹175 in February for mid-range gross (no Feb override for that slab)" do
      result = calc(gross: 8_000, month: 2)
      expect(result.amount).to eq(175)   # no february slab for 7501–10000
    end
  end

  # ── Karnataka (no February special) ──────────────────────────────────────

  context "Karnataka — any month" do
    let(:setting) { build(:payroll_setting, tenant: tenant, pt_enabled: true, pt_state: "karnataka") }

    before { seed_ka_slabs(tenant) }

    it "returns ₹0 for gross ≤ ₹15,000" do
      result = calc(gross: 14_000)
      expect(result.amount).to eq(0)
    end

    it "returns ₹200 for gross above ₹15,000" do
      result = calc(gross: 50_000)
      expect(result.amount).to eq(200)
    end

    it "returns the same ₹200 in February (no February override)" do
      result = calc(gross: 50_000, month: 2)
      expect(result.amount).to eq(200)
    end
  end

  # ── PT disabled for tenant ────────────────────────────────────────────────

  context "when PT is disabled in PayrollSetting" do
    let(:setting) { build(:payroll_setting, tenant: tenant, pt_enabled: false, pt_state: nil) }

    it "returns zero result" do
      result = calc(gross: 81_533)
      expect(result.applicable).to be false
      expect(result.amount).to eq(0)
    end
  end

  # ── Employee opted out ────────────────────────────────────────────────────

  context "when employee has pt_applicable = false" do
    let(:employee) { build(:employee, tenant: tenant, pt_applicable: false) }

    before { seed_mh_slabs(tenant) }

    it "returns zero result" do
      result = calc(gross: 81_533)
      expect(result.applicable).to be false
      expect(result.amount).to eq(0)
    end
  end

  # ── No slabs seeded ───────────────────────────────────────────────────────

  context "when no slabs are seeded for the tenant" do
    it "returns zero result (no slab found)" do
      result = calc(gross: 81_533)
      expect(result.applicable).to be false
    end
  end
end
