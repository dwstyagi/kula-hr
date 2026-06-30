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

    def self.call(annual_ctc:, salary_structure:, payroll_setting:, professional_tax_slabs: [], apply_employer_pf_carve: nil)
      new(annual_ctc, salary_structure, payroll_setting, professional_tax_slabs)
        .call(apply_employer_pf_carve: apply_employer_pf_carve)
    end

    def initialize(annual_ctc, salary_structure, payroll_setting, professional_tax_slabs)
      @annual_ctc = annual_ctc.to_d
      @monthly_ctc = (@annual_ctc / 12).round(2)
      @structure = salary_structure
      @settings = payroll_setting
      @pt_slabs = professional_tax_slabs
      @components = salary_structure.salary_structure_components.includes(:salary_component)
    end

    # apply_employer_pf_carve: nil → follow the tenant setting; true/false forces it.
    # The payroll path (SalaryCalculator) passes false and carves itself, post-proration.
    def call(apply_employer_pf_carve: nil)
      earnings = compute_earnings
      basic_monthly = find_basic_monthly(earnings)

      employer_pf, pf_admin, edli = employer_pf_charges(basic_monthly)

      carve = apply_employer_pf_carve.nil? ? @settings.employer_pf_in_ctc? : apply_employer_pf_carve
      reduce_special_allowance!(earnings, employer_pf + pf_admin + edli) if carve

      gross_monthly = earnings.sum(&:monthly)
      gross_annual = earnings.sum(&:annual)

      deductions = compute_deductions(basic_monthly, gross_monthly)
      total_deductions_monthly = deductions.sum(&:monthly)

      employer_contributions = build_employer_contributions(employer_pf, pf_admin, edli, gross_monthly)
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

    def find_basic_monthly(earnings)
      basic = earnings.find { |e| e.name == "Basic" }
      basic&.monthly || 0
    end

    def compute_deductions(basic_monthly, gross_monthly)
      deductions = []

      # Employee PF: rate% of Basic, capped at ceiling
      pf_base = [ basic_monthly, @settings.pf_wage_ceiling ].min
      employee_pf = (pf_base * @settings.pf_employee_rate / 100).round(2)
      deductions << LineItem.new(name: "Employee PF", component_type: "deduction", monthly: employee_pf, annual: (employee_pf * 12).round(2))

      # ESI: rate% of Gross, only if gross <= ceiling
      if gross_monthly <= @settings.esi_ceiling
        esi = (gross_monthly * @settings.esi_employee_rate / 100).round(2)
      else
        esi = 0
      end
      deductions << LineItem.new(name: "ESI", component_type: "deduction", monthly: esi, annual: (esi * 12).round(2))

      # Professional Tax: state-wise slab lookup
      pt = compute_professional_tax(gross_monthly)
      deductions << LineItem.new(name: "Professional Tax", component_type: "deduction", monthly: pt, annual: (pt * 12).round(2))

      deductions
    end

    # Employer-side PF charges (monthly): [employer_pf, pf_admin, edli].
    # All computed on the capped PF wage base. Zero when PF is disabled.
    def employer_pf_charges(basic_monthly)
      return [ 0, 0, 0 ] unless @settings.pf_enabled?

      pf_base     = [ basic_monthly, @settings.pf_wage_ceiling ].min
      employer_pf = (pf_base * @settings.pf_employer_rate / 100).round(2)
      pf_admin    = (pf_base * @settings.pf_admin_charge_rate / 100).round(2)
      edli        = (pf_base * @settings.pf_edli_rate / 100).round(2)
      [ employer_pf, pf_admin, edli ]
    end

    def build_employer_contributions(employer_pf, pf_admin, edli, gross_monthly)
      contributions = []
      line = ->(name, amt) { LineItem.new(name: name, component_type: "employer_contribution", monthly: amt, annual: (amt * 12).round(2)) }

      contributions << line.call("Employer PF", employer_pf)
      contributions << line.call("PF Admin Charges", pf_admin) if pf_admin.positive?
      contributions << line.call("EDLI", edli) if edli.positive?

      employer_esi = gross_monthly <= @settings.esi_ceiling ? (gross_monthly * @settings.esi_employer_rate / 100).round(2) : 0
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
