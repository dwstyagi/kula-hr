module Statutory
  class EsiCalculator
    EsiResult = Struct.new(
      :employee_amount,  # Employee ESI deduction (payslip deduction)
      :employer_amount,  # Employer ESI contribution (CTC component, not on payslip)
      :gross_used,       # Gross salary used for calculation
      :applicable,       # Was ESI calculated?
      keyword_init: true
    )

    ZERO_RESULT = EsiResult.new(
      employee_amount: 0, employer_amount: 0, gross_used: 0, applicable: false
    ).freeze

    # gross   — monthly gross salary (all earnings combined)
    # setting — PayrollSetting record
    def initialize(gross:, setting:)
      @gross   = gross.to_d
      @setting = setting
    end

    def call
      return ZERO_RESULT unless @setting.esi_enabled?
      return ZERO_RESULT unless eligible?

      employee_amount = (@setting.esi_employee_rate / 100 * @gross).ceil
      employer_amount = (@setting.esi_employer_rate / 100 * @gross).ceil

      EsiResult.new(
        employee_amount: employee_amount,
        employer_amount: employer_amount,
        gross_used:      @gross,
        applicable:      true
      )
    end

    private

    def eligible?
      @gross <= @setting.esi_ceiling
    end
  end
end
