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
      :rebate,
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
      taxable_income: 0, annual_tax: 0, rebate: 0, cess: 0,
      total_tax_with_cess: 0, monthly_tds: 0, regime: nil, applicable: false
    ).freeze

    # ── Statutory rates, keyed by financial year ─────────────────────────────
    #
    # When a Finance Act changes the rates, ADD a new entry — never edit a past
    # financial year. A payroll rerun for an earlier year must reproduce the
    # figures that were applied at the time.
    #
    # FY 2025-26 and FY 2026-27 share one rate set: Budget 2025 replaced the
    # Finance Act 2024 new-regime slabs, and Budget 2026 left the slabs, cess,
    # rebate and standard deduction unchanged.
    #
    # rebate_limit    — 87A: rebate applies when taxable income is at or below this
    # rebate_cap      — 87A: maximum rebate available
    # marginal_relief — 87A: cap tax at the income above rebate_limit (new regime only)
    FY_2025_26_RATES = {
      old_regime: {
        slabs: [
          { from: 0,          to: 250_000,    rate: 0  },
          { from: 250_000,    to: 500_000,    rate: 5  },
          { from: 500_000,    to: 1_000_000,  rate: 20 },
          { from: 1_000_000,  to: nil,        rate: 30 }
        ].freeze,
        standard_deduction: 50_000,
        rebate_limit:       500_000,
        rebate_cap:         12_500,
        marginal_relief:    false
      }.freeze,

      new_regime: {
        slabs: [
          { from: 0,          to: 400_000,    rate: 0  },
          { from: 400_000,    to: 800_000,    rate: 5  },
          { from: 800_000,    to: 1_200_000,  rate: 10 },
          { from: 1_200_000,  to: 1_600_000,  rate: 15 },
          { from: 1_600_000,  to: 2_000_000,  rate: 20 },
          { from: 2_000_000,  to: 2_400_000,  rate: 25 },
          { from: 2_400_000,  to: nil,        rate: 30 }
        ].freeze,
        standard_deduction: 75_000,
        rebate_limit:       1_200_000,
        rebate_cap:         60_000,
        marginal_relief:    true
      }.freeze,

      cess_rate: 4
    }.freeze

    RATES_BY_FY = {
      "2025-26" => FY_2025_26_RATES,
      "2026-27" => FY_2025_26_RATES
    }.freeze

    # employee          — Employee record
    # annual_gross      — projected annual gross salary
    # monthly_basic     — for EPF auto-contribution under 80C + HRA calc
    # monthly_hra       — monthly HRA component received (for HRA exemption)
    # financial_year    — "2025-26"; also selects the rate set from RATES_BY_FY
    # month             — current payroll month (1–12)
    # ytd_tds_deducted  — TDS already deducted April through previous month
    def initialize(employee:, annual_gross:, monthly_basic: 0, monthly_hra: 0,
                   financial_year:, month:, ytd_tds_deducted: 0, declaration: :load)
      @employee         = employee
      @annual_gross     = annual_gross.to_d
      @monthly_basic    = monthly_basic.to_d
      @monthly_hra      = monthly_hra.to_d
      @financial_year   = financial_year
      @month            = month
      @ytd_tds_deducted = ytd_tds_deducted.to_d
      @declaration      = declaration == :load ? load_declaration : declaration
      @rates            = rates_for(financial_year)
    end

    def call
      return ZERO_RESULT if @annual_gross <= 0

      regime     = determine_regime
      deductions = calculate_deductions(regime)
      taxable    = [ @annual_gross - deductions[:total], 0 ].max.to_i

      # Rebate reduces the tax BEFORE cess; cess is charged on what remains.
      slab_tax   = calculate_tax(taxable, regime)
      annual_tax = apply_rebate(slab_tax, taxable, regime)
      cess       = (annual_tax * @rates[:cess_rate] / 100.0).round(0).to_i
      total_tax  = annual_tax + cess
      monthly    = calculate_monthly_tds(total_tax)

      TdsResult.new(
        annual_gross:        @annual_gross.to_i,
        standard_deduction:  deductions[:standard_deduction].to_i,
        section_80c:         deductions[:section_80c].to_i,
        section_80d:         deductions[:section_80d].to_i,
        section_80ccd1b:     deductions[:section_80ccd1b].to_i,
        hra_exemption:       deductions[:hra_exemption].to_i,
        home_loan_interest:  deductions[:home_loan_interest].to_i,
        other_deductions:    deductions[:other].to_i,
        total_deductions:    deductions[:total].to_i,
        taxable_income:      taxable,
        annual_tax:          annual_tax,
        rebate:              slab_tax - annual_tax,
        cess:                cess,
        total_tax_with_cess: total_tax,
        monthly_tds:         monthly,
        regime:              regime,
        applicable:          monthly > 0
      )
    end

    private

    # ── Rate lookup ─────────────────────────────────────────────────────────

    # Falls back to the most recent configured year rather than raising: an
    # unconfigured FY must not block payroll for every tenant on 1 April. The
    # warning is the signal to add the new Finance Act rates.
    def rates_for(financial_year)
      RATES_BY_FY.fetch(financial_year) do
        latest_fy, latest_rates = RATES_BY_FY.max_by { |fy, _| fy }
        Rails.logger.warn(
          "[TdsCalculator] No tax rates configured for FY #{financial_year}; " \
          "using FY #{latest_fy}. Add the current Finance Act rates to RATES_BY_FY."
        )
        latest_rates
      end
    end

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

      # The standard deduction differs by regime — ₹75,000 under the new regime,
      # ₹50,000 under the old one.
      d[:standard_deduction] = @rates.fetch(regime)[:standard_deduction]

      d[:total] = d[:standard_deduction] +
                  d[:section_80c] + d[:section_80d] + d[:section_80ccd1b] +
                  d[:hra_exemption] + d[:home_loan_interest] + d[:other]
      d
    end

    # ── Old Regime deduction calculators ────────────────────────────────────

    def investment_total(sections)
      if @declaration.association(:investment_declarations).loaded?
        @declaration.investment_declarations.select { |item| sections.include?(item.section) }.sum(&:declared_amount)
      else
        @declaration.investment_declarations.where(section: sections).sum(:declared_amount)
      end
    end

    def calculate_80c
      declared = with_tenant do
        investment_total([ "80C" ])
      end

      # EPF employee contribution auto-counts under 80C
      epf_auto     = (@monthly_basic * 12 * 0.12).round(0)
      home_principal = @declaration.home_loan_principal.to_f

      total = declared.to_f + epf_auto + home_principal
      [ total, 150_000 ].min.to_i
    end

    def calculate_80d
      declared = with_tenant do
        investment_total([ "80D" ])
      end
      [ declared.to_f, 50_000 ].min.to_i
    end

    def investment_total(sections)
      if @declaration.association(:investment_declarations).loaded?
        @declaration.investment_declarations.select { |item| sections.include?(item.section) }.sum(&:declared_amount)
      else
        @declaration.investment_declarations.where(section: sections).sum(:declared_amount)
      end
    end

    def calculate_80ccd1b
      declared = with_tenant do
        investment_total([ "80CCD1B" ])
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
        investment_total(%w[80E 80G 80TTA])
                    .to_i
      end
    end

    # ── Tax slab calculation ─────────────────────────────────────────────────

    def calculate_tax(taxable_income, regime)
      slabs = @rates.fetch(regime)[:slabs]
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

    # Section 87A. Returns the tax payable after rebate, before cess.
    def apply_rebate(slab_tax, taxable_income, regime)
      rules = @rates.fetch(regime)

      if taxable_income <= rules[:rebate_limit]
        [ slab_tax - rules[:rebate_cap], 0 ].max
      elsif rules[:marginal_relief]
        # Without this, crossing the limit by ₹1 would cost the whole rebate.
        # Tax is capped at the income earned above the limit.
        [ slab_tax, taxable_income - rules[:rebate_limit] ].min
      else
        slab_tax
      end
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
