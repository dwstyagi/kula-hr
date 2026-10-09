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

    # gross               — monthly gross salary (all earnings combined)
    # setting             — PayrollSetting record
    # continuing_coverage — ESI was deducted earlier in the current contribution
    #                       period (Apr–Sep / Oct–Mar). Coverage then continues
    #                       to the end of the period even if gross now exceeds
    #                       the ceiling.
    def initialize(gross:, setting:, continuing_coverage: false)
      @gross               = gross.to_d
      @setting             = setting
      @continuing_coverage = continuing_coverage
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
      return false unless @gross.positive?

      @continuing_coverage || @gross <= @setting.esi_ceiling
    end
  end
end
