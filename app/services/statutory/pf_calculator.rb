module Statutory
  class PfCalculator
    PfResult = Struct.new(
      :employee_pf,    # Employee contribution (payslip deduction)
      :employer_pf,    # Employer total contribution (CTC component, not on payslip)
      :eps_amount,     # Employer → EPS portion
      :epf_amount,     # Employer → EPF portion
      :pf_base,        # Wage base used for calculation
      :admin_charge,   # 0.5% employer admin charge
      :edli_charge,    # 0.5% EDLI insurance
      :applicable,
      keyword_init: true
    )

    ZERO_RESULT = PfResult.new(
      employee_pf: 0, employer_pf: 0, eps_amount: 0, epf_amount: 0,
      pf_base: 0, admin_charge: 0, edli_charge: 0, applicable: false
    ).freeze

    # basic   — monthly Basic salary
    # da      — monthly DA (Dearness Allowance), default 0
    # setting — PayrollSetting record
    # employee — Employee record
    def initialize(basic:, da: 0, setting:, employee:)
      @basic    = basic.to_d
      @da       = da.to_d
      @setting  = setting
      @employee = employee
    end

    def call
      return ZERO_RESULT unless @setting.pf_enabled?
      return ZERO_RESULT unless @employee.pf_applicable?

      pf_base       = calculate_pf_base
      employee_pf   = (@setting.pf_employee_rate / 100 * pf_base).round(0).to_i
      employer_total = (@setting.pf_employer_rate / 100 * pf_base).round(0).to_i

      # EPS base is ALWAYS capped at wage ceiling, even when pf_on_full_basic is true
      eps_base   = [ pf_base, @setting.pf_wage_ceiling ].min
      eps_amount = (8.33 / 100 * eps_base).round(0).to_i
      epf_amount = employer_total - eps_amount

      # Admin charges are also on the capped base
      admin_charge = (@setting.pf_admin_charge_rate / 100 * eps_base).round(0).to_i
      edli_charge  = (@setting.pf_edli_rate          / 100 * eps_base).round(0).to_i

      PfResult.new(
        employee_pf:  employee_pf,
        employer_pf:  employer_total,
        eps_amount:   eps_amount,
        epf_amount:   epf_amount,
        pf_base:      pf_base,
        admin_charge: admin_charge,
        edli_charge:  edli_charge,
        applicable:   true
      )
    end

    private

    def calculate_pf_base
      raw = @setting.pf_include_da? ? (@basic + @da) : @basic

      if @employee.pf_on_full_basic?
        raw                                                    # no ceiling
      else
        [ raw, @setting.pf_wage_ceiling ].min                 # capped
      end
    end
  end
end
