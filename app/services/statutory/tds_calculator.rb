module Statutory
  class TdsCalculator
    TdsResult = Struct.new(
      :annual_gross,
      :standard_deduction,
      :section_80c,
      :section_80d,
      :section_80ccd1b,
      :hra_exemption,
      :home_loan_interest,
      :other_deductions,
      :total_deductions,
      :taxable_income,
      :annual_tax,
      :cess,
      :total_tax_with_cess,
      :monthly_tds,
      :regime,
      :applicable,
      keyword_init: true
    )

    ZERO_RESULT = TdsResult.new(
      annual_gross: 0, standard_deduction: 0, section_80c: 0,
      section_80d: 0, section_80ccd1b: 0, hra_exemption: 0,
      home_loan_interest: 0, other_deductions: 0, total_deductions: 0,
      taxable_income: 0, annual_tax: 0, cess: 0,
      total_tax_with_cess: 0, monthly_tds: 0, regime: nil, applicable: false
    ).freeze

    # FY 2024-25 / 2025-26 slabs (Finance Act 2024)
    OLD_REGIME_SLABS = [
      { from: 0,          to: 250_000,    rate: 0  },
      { from: 250_000,    to: 500_000,    rate: 5  },
      { from: 500_000,    to: 1_000_000,  rate: 20 },
      { from: 1_000_000,  to: nil,        rate: 30 }
    ].freeze

    NEW_REGIME_SLABS = [
      { from: 0,          to: 300_000,    rate: 0  },
      { from: 300_000,    to: 700_000,    rate: 5  },
      { from: 700_000,    to: 1_000_000,  rate: 10 },
      { from: 1_000_000,  to: 1_200_000,  rate: 15 },
      { from: 1_200_000,  to: 1_500_000,  rate: 20 },
      { from: 1_500_000,  to: nil,        rate: 30 }
    ].freeze

    STANDARD_DEDUCTION      = 75_000
    CESS_RATE               = 4
    OLD_REGIME_REBATE_LIMIT = 500_000   # 87A: no tax if taxable ≤ ₹5L (old regime)
    NEW_REGIME_REBATE_LIMIT = 700_000   # 87A: no tax if taxable ≤ ₹7L (new regime)

    # employee          — Employee record
    # annual_gross      — projected annual gross salary
    # monthly_basic     — for EPF auto-contribution under 80C + HRA calc
    # monthly_hra       — monthly HRA component received (for HRA exemption)
    # financial_year    — "2025-26"
    # month             — current payroll month (1–12)
    # ytd_tds_deducted  — TDS already deducted April through previous month
    def initialize(employee:, annual_gross:, monthly_basic: 0, monthly_hra: 0,
                   financial_year:, month:, ytd_tds_deducted: 0)
      @employee         = employee
      @annual_gross     = annual_gross.to_d
      @monthly_basic    = monthly_basic.to_d
      @monthly_hra      = monthly_hra.to_d
      @financial_year   = financial_year
      @month            = month
      @ytd_tds_deducted = ytd_tds_deducted.to_d
      @declaration      = load_declaration
    end

    def call
      return ZERO_RESULT if @annual_gross <= 0

      regime     = determine_regime
      deductions = calculate_deductions(regime)
      taxable    = [ @annual_gross - deductions[:total], 0 ].max.to_i

      annual_tax = calculate_tax(taxable, regime)
      cess       = (annual_tax * CESS_RATE / 100.0).round(0).to_i
      total_tax  = annual_tax + cess
      total_tax  = apply_rebate(total_tax, taxable, regime)
      monthly    = calculate_monthly_tds(total_tax)

      TdsResult.new(
        annual_gross:        @annual_gross.to_i,
        standard_deduction:  STANDARD_DEDUCTION,
        section_80c:         deductions[:section_80c].to_i,
        section_80d:         deductions[:section_80d].to_i,
        section_80ccd1b:     deductions[:section_80ccd1b].to_i,
        hra_exemption:       deductions[:hra_exemption].to_i,
        home_loan_interest:  deductions[:home_loan_interest].to_i,
        other_deductions:    deductions[:other].to_i,
        total_deductions:    deductions[:total].to_i,
        taxable_income:      taxable,
        annual_tax:          annual_tax,
        cess:                cess,
        total_tax_with_cess: total_tax,
        monthly_tds:         monthly,
        regime:              regime,
        applicable:          monthly > 0
      )
    end

    private

    # ── Tenant-scoped DB access ─────────────────────────────────────────────

    def with_tenant(&block)
      ActsAsTenant.with_tenant(@employee.tenant, &block)
    end

    def load_declaration
      with_tenant do
        TaxDeclaration.find_by(employee: @employee, financial_year: @financial_year)
      end
    end

    # ── Regime + Deductions ─────────────────────────────────────────────────

    def determine_regime
      return :new_regime unless @declaration
      @declaration.regime.to_sym   # "old_regime" or "new_regime"
    end

    def calculate_deductions(regime)
      if regime == :old_regime && @declaration
        d = {
          section_80c:       calculate_80c,
          section_80d:       calculate_80d,
          section_80ccd1b:   calculate_80ccd1b,
          hra_exemption:     calculate_hra_exemption,
          home_loan_interest: calculate_home_loan_interest,
          other:             calculate_other_deductions
        }
      else
        d = {
          section_80c: 0, section_80d: 0, section_80ccd1b: 0,
          hra_exemption: 0, home_loan_interest: 0, other: 0
        }
      end

      d[:total] = STANDARD_DEDUCTION +
                  d[:section_80c] + d[:section_80d] + d[:section_80ccd1b] +
                  d[:hra_exemption] + d[:home_loan_interest] + d[:other]
      d
    end

    # ── Old Regime deduction calculators ────────────────────────────────────

    def calculate_80c
      declared = with_tenant do
        @declaration.investment_declarations.where(section: "80C").sum(:declared_amount)
      end

      # EPF employee contribution auto-counts under 80C
      epf_auto     = (@monthly_basic * 12 * 0.12).round(0)
      home_principal = @declaration.home_loan_principal.to_f

      total = declared.to_f + epf_auto + home_principal
      [ total, 150_000 ].min.to_i
    end

    def calculate_80d
      declared = with_tenant do
        @declaration.investment_declarations.where(section: "80D").sum(:declared_amount)
      end
      [ declared.to_f, 50_000 ].min.to_i
    end

    def calculate_80ccd1b
      declared = with_tenant do
        @declaration.investment_declarations.where(section: "80CCD1B").sum(:declared_amount)
      end
      [ declared.to_f, 50_000 ].min.to_i
    end

    def calculate_hra_exemption
      return 0 unless @declaration.claiming_hra?
      return 0 if @monthly_hra.zero?

      annual_hra   = @monthly_hra * 12
      annual_rent  = @declaration.monthly_rent.to_f * 12
      annual_basic = @monthly_basic * 12
      metro        = @declaration.rental_city == "metro"
      metro_pct    = metro ? 50 : 40

      # HRA exemption = MINIMUM of:
      #   1. Actual HRA received
      #   2. Rent paid minus 10% of basic salary
      #   3. 50% of basic (metro) or 40% of basic (non-metro)
      exemption = [
        annual_hra,
        [ annual_rent - (annual_basic * 0.10), 0 ].max,
        annual_basic * metro_pct / 100.0
      ].min

      exemption.round(0).to_i
    end

    def calculate_home_loan_interest
      interest = @declaration.home_loan_interest.to_f
      [ interest, 200_000 ].min.to_i   # Section 24(b) cap ₹2L
    end

    def calculate_other_deductions
      with_tenant do
        @declaration.investment_declarations
                    .where(section: %w[80E 80G 80TTA])
                    .sum(:declared_amount)
                    .to_i
      end
    end

    # ── Tax slab calculation ─────────────────────────────────────────────────

    def calculate_tax(taxable_income, regime)
      slabs = regime == :old_regime ? OLD_REGIME_SLABS : NEW_REGIME_SLABS
      tax   = 0.0

      slabs.each do |slab|
        lower = slab[:from]
        upper = slab[:to] || Float::INFINITY
        rate  = slab[:rate]

        next if taxable_income <= lower

        taxable_in_slab = [ taxable_income, upper ].min - lower
        tax += taxable_in_slab * rate / 100.0
      end

      tax.round(0).to_i
    end

    def apply_rebate(total_tax, taxable_income, regime)
      limit = regime == :old_regime ? OLD_REGIME_REBATE_LIMIT : NEW_REGIME_REBATE_LIMIT
      taxable_income <= limit ? 0 : total_tax
    end

    # ── Progressive monthly TDS ──────────────────────────────────────────────

    def calculate_monthly_tds(total_annual_tax)
      return 0 if total_annual_tax <= 0

      remaining_months = months_remaining_in_fy
      return 0 if remaining_months <= 0

      remaining_tax = [ total_annual_tax - @ytd_tds_deducted, 0 ].max
      (remaining_tax / remaining_months).round(0).to_i
    end

    def months_remaining_in_fy
      # FY runs April (month 4) through March (month 3)
      # April = position 1, March = position 12
      month_in_fy = @month >= 4 ? (@month - 3) : (@month + 9)
      13 - month_in_fy
    end
  end
end
