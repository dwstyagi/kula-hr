require "rails_helper"

RSpec.describe Statutory::TdsCalculator do
  let(:tenant)   { create(:tenant) }
  let(:employee) { ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) } }

  def calc(annual_gross:, month: 2, monthly_basic: 0, monthly_hra: 0, ytd_tds_deducted: 0)
    described_class.new(
      employee:         employee,
      annual_gross:     annual_gross,
      monthly_basic:    monthly_basic,
      monthly_hra:      monthly_hra,
      financial_year:   "2025-26",
      month:            month,
      ytd_tds_deducted: ytd_tds_deducted
    ).call
  end

  def create_declaration(attrs = {}, investments = [])
    ActsAsTenant.with_tenant(tenant) do
      decl = create(:tax_declaration,
        attrs.reverse_merge(
          tenant: tenant, employee: employee,
          financial_year: "2025-26", regime: :old_regime
        )
      )
      investments.each do |inv|
        create(:investment_declaration, inv.merge(tenant: tenant, tax_declaration: decl))
      end
      decl
    end
  end

  # ── Zero / guard ────────────────────────────────────────────────────────────

  context "when annual_gross is zero" do
    it "returns zero result" do
      result = calc(annual_gross: 0)
      expect(result.applicable).to be false
      expect(result.monthly_tds).to eq(0)
    end
  end

  # ── New Regime (default — no declaration) ───────────────────────────────────

  context "New Regime — no declaration submitted (defaults to new regime)" do
    it "applies only standard deduction" do
      result = calc(annual_gross: 978_400, month: 4)  # April = 12 months remaining
      expect(result.regime).to eq(:new_regime)
      expect(result.standard_deduction).to eq(75_000)
      expect(result.section_80c).to eq(0)
      expect(result.taxable_income).to eq(903_400)
    end

    it "calculates correct tax on ₹9,03,400 taxable income" do
      result = calc(annual_gross: 978_400, month: 4)
      # 0-3L: 0, 3L-7L: 20000, 7L-9.034L: 20340 → 40340
      expect(result.annual_tax).to eq(40_340)
    end

    it "adds 4% cess" do
      result = calc(annual_gross: 978_400, month: 4)
      expect(result.cess).to eq(1_614)         # 40340 × 4% = 1613.6 → 1614
      expect(result.total_tax_with_cess).to eq(41_954)
    end

    it "calculates monthly TDS by dividing over remaining months" do
      result = calc(annual_gross: 978_400, month: 4)  # 12 months remaining
      expect(result.monthly_tds).to eq(3_496)         # 41954 / 12 = 3496.2 → 3496
    end
  end

  # ── 87A Rebate: New Regime (taxable ≤ ₹7L → zero tax) ──────────────────────

  context "87A rebate — New Regime, taxable ≤ ₹7,00,000" do
    it "gives full rebate and zero monthly TDS" do
      # annual_gross = 750_000, taxable = 750k - 75k = 675k ≤ 700k
      result = calc(annual_gross: 750_000, month: 4)
      expect(result.taxable_income).to eq(675_000)
      expect(result.total_tax_with_cess).to eq(0)
      expect(result.monthly_tds).to eq(0)
    end
  end

  # ── Low salary: no tax at all ────────────────────────────────────────────────

  context "when salary is very low (below all slabs after deduction)" do
    it "returns zero TDS" do
      result = calc(annual_gross: 300_000, month: 4)
      # taxable = 300k - 75k = 225k → 0% slab
      expect(result.annual_tax).to eq(0)
      expect(result.monthly_tds).to eq(0)
    end
  end

  # ── Old Regime with 80C investments ─────────────────────────────────────────

  context "Old Regime with 80C investments" do
    before do
      create_declaration(
        { regime: :old_regime },
        [ { section: "80C", description: "PPF", declared_amount: 50_000 } ]
      )
    end

    it "applies 80C deduction (capped at ₹1,50,000)" do
      # EPF auto: 0 (monthly_basic not passed), declared: 50k → total 80C = 50k
      result = calc(annual_gross: 978_400, month: 4)
      expect(result.section_80c).to eq(50_000)
    end

    it "reduces taxable income by 80C amount" do
      result = calc(annual_gross: 978_400, month: 4)
      # taxable = 978400 - 75000 (std) - 50000 (80C) = 853400
      expect(result.taxable_income).to eq(853_400)
    end
  end

  # ── 80C cap at ₹1,50,000 ────────────────────────────────────────────────────

  context "80C cap" do
    before do
      create_declaration(
        { regime: :old_regime },
        [ { section: "80C", description: "ELSS + LIC", declared_amount: 200_000 } ]
      )
    end

    it "caps 80C at ₹1,50,000 even if declared more" do
      result = calc(annual_gross: 978_400, month: 4)
      expect(result.section_80c).to eq(150_000)
    end
  end

  # ── 80C with EPF auto-contribution ─────────────────────────────────────────

  context "80C with EPF auto-contribution (monthly_basic provided)" do
    before { create_declaration({ regime: :old_regime }) }

    it "adds EPF (12% of annual basic) to 80C automatically" do
      # monthly_basic = 33333 → EPF = 33333 × 12 × 12% = 47999.52 → round(0) = 48000
      # declared 80C = 0 → total = 48000 (under 1.5L cap)
      result = calc(annual_gross: 978_400, month: 4, monthly_basic: 33_333)
      expect(result.section_80c).to eq(48_000)
    end
  end

  # ── Old Regime with 80D ─────────────────────────────────────────────────────

  context "Old Regime with 80D medical insurance" do
    before do
      create_declaration(
        { regime: :old_regime },
        [ { section: "80D", description: "Health Insurance", declared_amount: 30_000 } ]
      )
    end

    it "deducts 80D amount (capped at ₹50,000)" do
      result = calc(annual_gross: 978_400, month: 4)
      expect(result.section_80d).to eq(30_000)
    end
  end

  # ── Old Regime: 87A rebate (taxable ≤ ₹5L) ──────────────────────────────────

  context "87A rebate — Old Regime, taxable ≤ ₹5,00,000" do
    before do
      create_declaration(
        { regime: :old_regime },
        [
          { section: "80C",     description: "PPF",     declared_amount: 150_000 },
          { section: "80D",     description: "Medical",  declared_amount: 35_000  },
          { section: "80CCD1B", description: "NPS",      declared_amount: 50_000  }
        ]
      )
    end

    it "gives full rebate when taxable income ≤ ₹5L" do
      # annual_gross 800000, std 75k, 80C 150k, 80D 35k, 80CCD1B 50k
      # taxable = 800000 - 310000 = 490000 ≤ 500000 → full 87A rebate
      result = calc(annual_gross: 800_000, month: 4)
      expect(result.taxable_income).to be <= 500_000
      expect(result.total_tax_with_cess).to eq(0)
      expect(result.monthly_tds).to eq(0)
    end
  end

  # ── HRA Exemption ────────────────────────────────────────────────────────────

  context "HRA exemption (Old Regime, metro city)" do
    before do
      create_declaration(regime: :old_regime, claiming_hra: true,
                         monthly_rent: 15_000, rental_city: "metro",
                         landlord_name: "Ramesh Kumar",
                         landlord_pan: "ABCDE1234F")   # required: annual rent ₹1.8L > ₹1L
    end

    it "calculates HRA exemption as minimum of three values" do
      # monthly_basic = 33333, monthly_hra = 16667
      # Actual HRA = 16667 × 12 = 200004
      # Rent - 10% basic = (15000×12) - (33333×12×10%) = 180000 - 40000 = 140000
      # 50% basic = 33333×12×50% = 200000
      # min(200004, 140000, 200000) = 140000
      result = calc(annual_gross: 978_400, month: 4,
                    monthly_basic: 33_333, monthly_hra: 16_667)
      expect(result.hra_exemption).to eq(140_000)
    end

    it "calculates HRA exemption correctly for non-metro (40%)" do
      ActsAsTenant.with_tenant(tenant) do
        TaxDeclaration.find_by(employee: employee, financial_year: "2025-26")
                      .update!(rental_city: "non_metro")
      end
      # 40% basic = 33333×12×40% = 160000
      # min(200004, 140000, 160000) = 140000
      result = calc(annual_gross: 978_400, month: 4,
                    monthly_basic: 33_333, monthly_hra: 16_667)
      expect(result.hra_exemption).to eq(140_000)
    end
  end

  # ── Progressive monthly TDS (YTD adjustment) ────────────────────────────────

  context "YTD progressive adjustment" do
    it "spreads remaining tax over remaining months" do
      # month = 1 (January), 3 months remaining (Jan, Feb, Mar)
      # annual tax = 41954, ytd deducted = 31464 (9 months × 3496)
      # remaining = 41954 - 31464 = 10490, monthly = 10490/3 = 3497
      result = calc(annual_gross: 978_400, month: 1, ytd_tds_deducted: 31_464)
      expect(result.monthly_tds).to eq(3_497)
    end

    it "returns 0 if YTD already covers the full liability" do
      result = calc(annual_gross: 978_400, month: 2, ytd_tds_deducted: 50_000)
      expect(result.monthly_tds).to eq(0)
    end
  end

  # ── months_remaining logic ────────────────────────────────────────────────────

  context "remaining months in FY" do
    it "returns 12 for April (start of FY)" do
      result = calc(annual_gross: 978_400, month: 4)
      # 41954 / 12 = 3496
      expect(result.monthly_tds).to eq(3_496)
    end

    it "returns 1 for March (last month of FY)" do
      result = calc(annual_gross: 978_400, month: 3, ytd_tds_deducted: 0)
      # All tax due in March
      expect(result.monthly_tds).to eq(result.total_tax_with_cess)
    end
  end
end
