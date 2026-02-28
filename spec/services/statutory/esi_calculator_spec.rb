require "rails_helper"

RSpec.describe Statutory::EsiCalculator do
  let(:tenant)  { create(:tenant) }
  let(:setting) { build(:payroll_setting, tenant: tenant) }

  def calc(gross:, s: setting)
    described_class.new(gross: gross, setting: s).call
  end

  # ── Eligible employee (gross ≤ ceiling) ──────────────────────────────────

  context "when gross is below the ESI ceiling" do
    it "marks result as applicable" do
      expect(calc(gross: 20_000).applicable).to be true
    end

    it "calculates employee ESI at 0.75% of gross (ceil)" do
      result = calc(gross: 20_000)
      expect(result.employee_amount).to eq(150)   # 20000 × 0.75% = 150.00
    end

    it "calculates employer ESI at 3.25% of gross (ceil)" do
      result = calc(gross: 20_000)
      expect(result.employer_amount).to eq(650)   # 20000 × 3.25% = 650.00
    end

    it "records the gross salary used" do
      result = calc(gross: 20_000)
      expect(result.gross_used).to eq(20_000)
    end
  end

  # ── Boundary: exactly at ceiling ─────────────────────────────────────────

  context "when gross equals the ESI ceiling exactly (₹21,000)" do
    it "is eligible" do
      expect(calc(gross: 21_000).applicable).to be true
    end

    it "calculates employee ESI correctly with ceil rounding" do
      result = calc(gross: 21_000)
      expect(result.employee_amount).to eq(158)   # 21000 × 0.75% = 157.5 → ceil = 158
    end

    it "calculates employer ESI correctly with ceil rounding" do
      result = calc(gross: 21_000)
      expect(result.employer_amount).to eq(683)   # 21000 × 3.25% = 682.5 → ceil = 683
    end
  end

  # ── Ineligible employee (gross > ceiling) ────────────────────────────────

  context "when gross exceeds the ESI ceiling" do
    it "returns zero result for gross one rupee above ceiling" do
      result = calc(gross: 21_001)
      expect(result.applicable).to be false
      expect(result.employee_amount).to eq(0)
      expect(result.employer_amount).to eq(0)
    end

    it "returns zero result for a high-salary employee" do
      result = calc(gross: 80_000)
      expect(result.applicable).to be false
      expect(result.employee_amount).to eq(0)
    end
  end

  # ── ESI disabled for tenant ───────────────────────────────────────────────

  context "when ESI is disabled in PayrollSetting" do
    let(:setting) { build(:payroll_setting, tenant: tenant, esi_enabled: false) }

    it "returns zero result regardless of gross" do
      result = calc(gross: 15_000)
      expect(result.applicable).to be false
      expect(result.employee_amount).to eq(0)
      expect(result.employer_amount).to eq(0)
    end
  end

  # ── Zero / edge cases ────────────────────────────────────────────────────

  context "edge cases" do
    it "returns zero result for zero gross" do
      result = calc(gross: 0)
      expect(result.employee_amount).to eq(0)
      expect(result.employer_amount).to eq(0)
    end

    it "handles fractional gross correctly (ceil rounds up)" do
      # gross = ₹15,333 → employee = 15333 × 0.75% = 114.9975 → ceil = 115
      result = calc(gross: 15_333)
      expect(result.employee_amount).to eq(115)
    end
  end
end
