require "rails_helper"

RSpec.describe Statutory::TdsCalculator do
  let(:tenant)   { create(:tenant) }
  let(:employee) { ActsAsTenant.with_tenant(tenant) { create(:employee, tenant: tenant) } }

  def calc(annual_gross:, month: 2, monthly_basic: 0, monthly_hra: 0,
           ytd_tds_deducted: 0, financial_year: "2025-26")
    described_class.new(
      employee:         employee,
      annual_gross:     annual_gross,
      monthly_basic:    monthly_basic,
      monthly_hra:      monthly_hra,
      financial_year:   financial_year,
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
    it "applies only standard deduction, at the new-regime ₹75,000" do
      result = calc(annual_gross: 978_400, month: 4)  # April = 12 months remaining
      expect(result.regime).to eq(:new_regime)
      expect(result.standard_deduction).to eq(75_000)
      expect(result.section_80c).to eq(0)
      expect(result.taxable_income).to eq(903_400)
    end

    it "rebates the whole liability — ₹9,03,400 taxable is under the ₹12L limit" do
      result = calc(annual_gross: 978_400, month: 4)
      # slab tax: 0-4L: 0, 4L-8L: 20000, 8L-9.034L: 10340 → 30340
      # 87A: taxable ≤ 12L → rebate min(30340, 60000) wipes it out
      expect(result.rebate).to eq(30_340)
      expect(result.annual_tax).to eq(0)
      expect(result.cess).to eq(0)
      expect(result.monthly_tds).to eq(0)
      expect(result.applicable).to be false
    end

    it "calculates tax across every slab above the rebate limit" do
      result = calc(annual_gross: 2_000_000, month: 4)
      # taxable = 19,25,000
      # 4-8L: 20000, 8-12L: 40000, 12-16L: 60000, 16L-19.25L: 65000 → 185000
      expect(result.taxable_income).to eq(1_925_000)
      expect(result.rebate).to eq(0)
      expect(result.annual_tax).to eq(185_000)
    end

    it "adds 4% cess" do
      result = calc(annual_gross: 2_000_000, month: 4)
      expect(result.cess).to eq(7_400)                  # 185000 × 4%
      expect(result.total_tax_with_cess).to eq(192_400)
    end

    it "calculates monthly TDS by dividing over remaining months" do
      result = calc(annual_gross: 2_000_000, month: 4)  # 12 months remaining
      expect(result.monthly_tds).to eq(16_033)          # 192400 / 12 = 16033.3
    end
  end

  # ── 87A Rebate: New Regime (taxable ≤ ₹12L → zero tax) ─────────────────────

  context "87A rebate — New Regime, taxable ≤ ₹12,00,000" do
    it "gives full rebate and zero monthly TDS at the ₹12.75L gross boundary" do
      # gross 12,75,000 − 75,000 standard deduction = 12,00,000 taxable
      result = calc(annual_gross: 1_275_000, month: 4)
      expect(result.taxable_income).to eq(1_200_000)
      expect(result.rebate).to eq(60_000)          # slab tax 60000, fully rebated
      expect(result.total_tax_with_cess).to eq(0)
      expect(result.monthly_tds).to eq(0)
    end
  end

  # ── 87A Marginal relief: New Regime, just above ₹12L ────────────────────────

  context "87A marginal relief — New Regime, taxable just above ₹12,00,000" do
    it "caps tax at the income earned above ₹12L" do
      # gross 12,85,000 − 75,000 = 12,10,000 taxable
      # slab tax = 60000 + (10000 × 15%) = 61500
      # marginal relief caps tax at the ₹10,000 earned above the limit
      result = calc(annual_gross: 1_285_000, month: 4)
      expect(result.taxable_income).to eq(1_210_000)
      expect(result.annual_tax).to eq(10_000)
      expect(result.rebate).to eq(51_500)
      expect(result.cess).to eq(400)
      expect(result.total_tax_with_cess).to eq(10_400)
    end

    it "stops binding once slab tax falls below the excess" do
      # gross 13,75,000 − 75,000 = 13,00,000 taxable
      # slab tax = 60000 + (100000 × 15%) = 75000, excess = 100000 → no relief
      result = calc(annual_gross: 1_375_000, month: 4)
      expect(result.annual_tax).to eq(75_000)
      expect(result.rebate).to eq(0)
      expect(result.total_tax_with_cess).to eq(78_000)
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

  # ── Rates are keyed by financial year ───────────────────────────────────────

  context "financial-year rate lookup" do
    it "applies the same rates to FY 2026-27 as FY 2025-26 (Budget 2026 made no change)" do
      fy_2025 = calc(annual_gross: 2_000_000, month: 4, financial_year: "2025-26")
      fy_2026 = calc(annual_gross: 2_000_000, month: 4, financial_year: "2026-27")
      expect(fy_2026.annual_tax).to eq(fy_2025.annual_tax)
      expect(fy_2026.total_tax_with_cess).to eq(192_400)
    end

    it "falls back to the latest configured year and warns for an unknown FY" do
      expect(Rails.logger).to receive(:warn).with(/No tax rates configured for FY 2099-00/)
      result = calc(annual_gross: 2_000_000, month: 4, financial_year: "2099-00")
      expect(result.total_tax_with_cess).to eq(192_400)
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

    it "uses the old-regime ₹50,000 standard deduction, not the new regime's ₹75,000" do
      result = calc(annual_gross: 978_400, month: 4)
      expect(result.regime).to eq(:old_regime)
      expect(result.standard_deduction).to eq(50_000)
    end

    it "reduces taxable income by 80C amount" do
      result = calc(annual_gross: 978_400, month: 4)
      # taxable = 978400 - 50000 (std) - 50000 (80C) = 878400
      expect(result.taxable_income).to eq(878_400)
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
      # annual_gross 785000, std 50k, 80C 150k, 80D 35k, 80CCD1B 50k
      # taxable = 785000 - 285000 = 500000 → slab tax 12500, fully rebated
      result = calc(annual_gross: 785_000, month: 4)
      expect(result.taxable_income).to eq(500_000)
      expect(result.rebate).to eq(12_500)
      expect(result.total_tax_with_cess).to eq(0)
      expect(result.monthly_tds).to eq(0)
    end

    it "gets no rebate and no marginal relief above ₹5L" do
      # taxable = 885000 - 285000 = 600000
      # slab tax = 12500 + (100000 × 20%) = 32500 — old regime has no marginal relief
      result = calc(annual_gross: 885_000, month: 4)
      expect(result.taxable_income).to eq(600_000)
      expect(result.rebate).to eq(0)
      expect(result.annual_tax).to eq(32_500)
      expect(result.total_tax_with_cess).to eq(33_800)
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
      # annual tax = 192400, ytd deducted = 144297 (9 months × 16033)
      # remaining = 192400 - 144297 = 48103, monthly = 48103/3 = 16034.3
      result = calc(annual_gross: 2_000_000, month: 1, ytd_tds_deducted: 144_297)
      expect(result.monthly_tds).to eq(16_034)
    end

    it "returns 0 if YTD already covers the full liability" do
      result = calc(annual_gross: 2_000_000, month: 2, ytd_tds_deducted: 200_000)
      expect(result.monthly_tds).to eq(0)
    end
  end

  # ── months_remaining logic ────────────────────────────────────────────────────

  context "remaining months in FY" do
    it "returns 12 for April (start of FY)" do
      result = calc(annual_gross: 2_000_000, month: 4)
      # 192400 / 12 = 16033
      expect(result.monthly_tds).to eq(16_033)
    end

    it "returns 1 for March (last month of FY)" do
      result = calc(annual_gross: 2_000_000, month: 3, ytd_tds_deducted: 0)
      # All tax due in March
      expect(result.monthly_tds).to eq(result.total_tax_with_cess)
    end
  end
end
