module Salary
  class CtcBreakupCalculator
    Result = Struct.new(
      :annual_ctc, :monthly_ctc,
      :earnings, :gross_monthly, :gross_annual,
      :deductions, :total_deductions_monthly,
      :employer_contributions, :total_employer_monthly,
      :net_monthly, :net_annual,
      keyword_init: true
    )

    LineItem = Struct.new(:name, :component_type, :monthly, :annual, keyword_init: true)

    # A preview is not for a particular employee: assume the default PF
    # coverage (covered, contribution capped at the ceiling).
    PreviewEmployee = Data.define do
      def pf_applicable? = true
      def pf_on_full_basic? = false
    end
    PREVIEW_EMPLOYEE = PreviewEmployee.new

    # pf_wage_ceiling: statutory ceiling for the month being previewed; defaults
    # to the ceiling in force this month (see Statutory::PfWageCeiling).
    def self.call(annual_ctc:, salary_structure:, payroll_setting:, professional_tax_slabs: [],
                  apply_employer_pf_carve: nil, pf_wage_ceiling: Statutory::PfWageCeiling.current)
      new(annual_ctc, salary_structure, payroll_setting, professional_tax_slabs, pf_wage_ceiling)
        .call(apply_employer_pf_carve: apply_employer_pf_carve)
    end

    def initialize(annual_ctc, salary_structure, payroll_setting, professional_tax_slabs,
                   pf_wage_ceiling = Statutory::PfWageCeiling.current)
      @pf_wage_ceiling = pf_wage_ceiling.to_d
      @annual_ctc = annual_ctc.to_d
      @monthly_ctc = (@annual_ctc / 12).round(2)
      @structure = salary_structure
      @settings = payroll_setting
      @pt_slabs = professional_tax_slabs
      @components = if salary_structure.association(:salary_structure_components).loaded?
        salary_structure.salary_structure_components
      else
        salary_structure.salary_structure_components.includes(:salary_component)
      end
    end

    # apply_employer_pf_carve: nil → follow the tenant setting; true/false forces it.
    # The payroll path (SalaryCalculator) passes false and carves itself, post-proration.
    def call(apply_employer_pf_carve: nil)
      earnings = compute_earnings
      pf = pf_result(earnings)
      employer_pf, pf_admin, edli = pf.employer_pf, pf.admin_charge, pf.edli_charge

      carve = apply_employer_pf_carve.nil? ? @settings.employer_pf_in_ctc? : apply_employer_pf_carve
      reduce_special_allowance!(earnings, employer_pf + pf_admin + edli) if carve

      gross_monthly = earnings.sum(&:monthly)
      gross_annual = earnings.sum(&:annual)

      esi = Statutory::EsiCalculator.new(gross: gross_monthly, setting: @settings).call
      deductions = compute_deductions(pf, esi, gross_monthly)
      total_deductions_monthly = deductions.sum(&:monthly)

      employer_contributions = build_employer_contributions(employer_pf, pf_admin, edli, esi.employer_amount)
      total_employer_monthly = employer_contributions.sum(&:monthly)

      net_monthly = (gross_monthly - total_deductions_monthly).round(2)
      net_annual = (net_monthly * 12).round(2)

      Result.new(
        annual_ctc: @annual_ctc,
        monthly_ctc: @monthly_ctc,
        earnings: earnings,
        gross_monthly: gross_monthly,
        gross_annual: gross_annual,
        deductions: deductions,
        total_deductions_monthly: total_deductions_monthly,
        employer_contributions: employer_contributions,
        total_employer_monthly: total_employer_monthly,
        net_monthly: net_monthly,
        net_annual: net_annual
      )
    end

    private

    def compute_earnings
      @components
        .select { |ssc| ssc.salary_component.earning? }
        .sort_by { |ssc| ssc.salary_component.sort_order }
        .map do |ssc|
          monthly = if ssc.salary_component.percentage?
            (@annual_ctc * ssc.value / 100 / 12).round(2)
          else
            ssc.value.round(2)
          end

          LineItem.new(
            name: ssc.salary_component.name,
            component_type: "earning",
            monthly: monthly,
            annual: (monthly * 12).round(2)
          )
        end
    end

    # PF, ESI and employer charges come from the same Statutory calculators
    # payroll uses, so the preview matches the payslip (PF/ESI enablement,
    # DA in the PF base, rupee rounding, ESI rounded up).
    def pf_result(earnings)
      amount = ->(*names) { earnings.find { |e| names.include?(e.name) }&.monthly || 0 }
      Statutory::PfCalculator.new(
        basic:        amount.call("Basic"),
        da:           amount.call("DA", "Dearness Allowance"),
        setting:      @settings,
        employee:     PREVIEW_EMPLOYEE,
        wage_ceiling: @pf_wage_ceiling
      ).call
    end

    def compute_deductions(pf, esi, gross_monthly)
      line = ->(name, amt) { LineItem.new(name: name, component_type: "deduction", monthly: amt, annual: (amt * 12).round(2)) }
      [
        line.call("Employee PF", pf.employee_pf),
        line.call("ESI", esi.employee_amount),
        line.call("Professional Tax", compute_professional_tax(gross_monthly))
      ]
    end

    def build_employer_contributions(employer_pf, pf_admin, edli, employer_esi)
      contributions = []
      line = ->(name, amt) { LineItem.new(name: name, component_type: "employer_contribution", monthly: amt, annual: (amt * 12).round(2)) }

      contributions << line.call("Employer PF", employer_pf)
      contributions << line.call("PF Admin Charges", pf_admin) if pf_admin.positive?
      contributions << line.call("EDLI", edli) if edli.positive?

      contributions << line.call("Employer ESI", employer_esi)
      contributions
    end

    # CTC-inclusive model: pull the employer PF charges out of Special Allowance
    # (the flexible residual) so the employee bears them. Never touches Basic/HRA
    # (keeps PF base and HRA exemption intact). Falls back to the largest other
    # earning, and floors at zero if the structure leaves nothing to carve.
    def reduce_special_allowance!(earnings, carve_amount)
      return if carve_amount <= 0

      target = earnings.find { |e| e.name == "Special Allowance" } ||
               earnings.reject { |e| %w[Basic HRA].include?(e.name) }.max_by(&:monthly)
      return unless target

      new_monthly = [ target.monthly - carve_amount, 0 ].max
      target.monthly = new_monthly
      target.annual  = (new_monthly * 12).round(2)
    end

    def compute_professional_tax(gross_monthly)
      # Find matching slab (non-February, general slab)
      slab = @pt_slabs
        .select { |s| s.month.blank? }
        .find { |s| gross_monthly >= s.salary_from && gross_monthly <= s.salary_to }

      slab&.tax_amount || 0
    end
  end
end
