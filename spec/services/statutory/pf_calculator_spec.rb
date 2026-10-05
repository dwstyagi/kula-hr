require "rails_helper"

RSpec.describe Statutory::PfCalculator do
  let(:tenant)   { create(:tenant) }
  let(:setting)  { build(:payroll_setting, tenant: tenant) }
  let(:employee) { build(:employee, tenant: tenant) }

  # Logic examples below use the pre-September-2026 ₹15,000 ceiling.
  def calc(basic:, da: 0, emp: employee, s: setting, ceiling: 15_000)
    described_class.new(basic: basic, da: da, setting: s, employee: emp, wage_ceiling: ceiling).call
  end

  # ── Standard employee (Basic > ceiling) ──────────────────────────────────

  context "when Basic exceeds the wage ceiling" do
    it "caps PF base at wage ceiling" do
      result = calc(basic: 33_333)
      expect(result.pf_base).to eq(15_000)
    end

    it "calculates employee PF at 12% of capped base" do
      result = calc(basic: 33_333)
      expect(result.employee_pf).to eq(1_800)   # 15000 × 12%
    end

    it "calculates employer PF at 12% of capped base" do
      result = calc(basic: 33_333)
      expect(result.employer_pf).to eq(1_800)
    end

    it "splits employer PF into EPS (8.33%) and EPF (remainder)" do
      result = calc(basic: 33_333)
      expect(result.eps_amount).to eq(1_250)     # 15000 × 8.33%
      expect(result.epf_amount).to eq(550)       # 1800 − 1250
    end

    it "marks result as applicable" do
      expect(calc(basic: 33_333).applicable).to be true
    end
  end

  # ── Low-salary employee (Basic < ceiling) ────────────────────────────────

  context "when Basic is below the wage ceiling" do
    it "uses actual Basic as PF base" do
      result = calc(basic: 12_000)
      expect(result.pf_base).to eq(12_000)
    end

    it "calculates employee PF on actual base" do
      result = calc(basic: 12_000)
      expect(result.employee_pf).to eq(1_440)   # 12000 × 12%
    end
  end

  # ── Dearness Allowance ────────────────────────────────────────────────────

  context "when pf_include_da is true (default)" do
    it "adds DA to PF base before applying ceiling" do
      result = calc(basic: 10_000, da: 3_000)
      expect(result.pf_base).to eq(13_000)       # 10k + 3k, under ceiling
    end

    it "caps Basic + DA at wage ceiling" do
      result = calc(basic: 12_000, da: 5_000)
      expect(result.pf_base).to eq(15_000)       # min(17000, 15000)
    end
  end

  context "when pf_include_da is false" do
    let(:setting) { build(:payroll_setting, tenant: tenant, pf_include_da: false) }

    it "ignores DA in PF base" do
      result = calc(basic: 10_000, da: 5_000)
      expect(result.pf_base).to eq(10_000)       # DA ignored
    end
  end

  # ── pf_on_full_basic flag ────────────────────────────────────────────────

  context "when employee has pf_on_full_basic = true" do
    let(:employee) { build(:employee, tenant: tenant, pf_on_full_basic: true) }

    it "calculates PF on full Basic without ceiling cap" do
      result = calc(basic: 50_000, emp: employee)
      expect(result.pf_base).to eq(50_000)
      expect(result.employee_pf).to eq(6_000)    # 50000 × 12%
    end

    it "still caps EPS at wage ceiling" do
      result = calc(basic: 50_000, emp: employee)
      expect(result.eps_amount).to eq(1_250)     # min(50k, 15k) × 8.33%
      expect(result.epf_amount).to eq(4_750)     # 6000 − 1250
    end
  end

  # ── Admin charge & EDLI ──────────────────────────────────────────────────

  context "admin charge and EDLI" do
    it "calculates admin_charge as 0.5% of capped base" do
      result = calc(basic: 33_333)
      expect(result.admin_charge).to eq(75)      # 15000 × 0.5%
    end

    it "calculates edli_charge as 0.5% of capped base" do
      result = calc(basic: 33_333)
      expect(result.edli_charge).to eq(75)
    end
  end

  # ── Opt-out: pf_applicable = false ───────────────────────────────────────

  context "when employee has pf_applicable = false" do
    let(:employee) { build(:employee, tenant: tenant, pf_applicable: false) }

    it "returns zero result" do
      result = calc(basic: 33_333)
      expect(result.applicable).to be false
      expect(result.employee_pf).to eq(0)
      expect(result.employer_pf).to eq(0)
    end
  end

  # ── PF disabled for tenant ───────────────────────────────────────────────

  context "when PF is disabled in PayrollSetting" do
    let(:setting) { build(:payroll_setting, tenant: tenant, pf_enabled: false) }

    it "returns zero result regardless of employee flags" do
      result = calc(basic: 33_333)
      expect(result.applicable).to be false
      expect(result.employee_pf).to eq(0)
    end
  end

  # ── Zero / edge cases ────────────────────────────────────────────────────

  context "edge cases" do
    it "returns zero result for zero basic" do
      result = calc(basic: 0)
      expect(result.employee_pf).to eq(0)
    end

    it "handles Basic exactly equal to wage ceiling" do
      result = calc(basic: 15_000)
      expect(result.pf_base).to eq(15_000)
      expect(result.employee_pf).to eq(1_800)
    end
  end

  # ── ₹25,000 ceiling (S.O. 5109(E), from 17 Sep 2026) ─────────────────────

  context "with the ₹25,000 wage ceiling" do
    it "caps the PF base at ₹25,000" do
      result = calc(basic: 40_000, ceiling: 25_000)
      expect(result.pf_base).to eq(25_000)
      expect(result.employee_pf).to eq(3_000)
      expect(result.employer_pf).to eq(3_000)
    end

    it "caps EPS at 8.33% of ₹25,000" do
      result = calc(basic: 40_000, ceiling: 25_000)
      expect(result.eps_amount).to eq(2_083)
      expect(result.epf_amount).to eq(917)
    end

    it "brings wages between ₹15,000 and ₹25,000 fully into the base" do
      result = calc(basic: 20_000, ceiling: 25_000)
      expect(result.pf_base).to eq(20_000)
      expect(result.employee_pf).to eq(2_400)
    end

    it "uses the ceiling in force this month when none is given" do
      travel_to(Date.new(2026, 10, 15)) do
        result = described_class.new(basic: 40_000, setting: setting, employee: employee).call
        expect(result.pf_base).to eq(25_000)
      end
    end
  end
end
