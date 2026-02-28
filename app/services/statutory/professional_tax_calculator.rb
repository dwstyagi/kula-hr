module Statutory
  class ProfessionalTaxCalculator
    PtResult = Struct.new(:amount, :state, :applicable, keyword_init: true)

    ZERO_RESULT = PtResult.new(amount: 0, state: nil, applicable: false).freeze

    # gross    — monthly gross salary
    # setting  — PayrollSetting record (provides pt_state, pt_enabled, tenant)
    # employee — Employee record (provides pt_applicable flag)
    # month    — integer month number 1–12
    def initialize(gross:, setting:, employee:, month:)
      @gross    = gross.to_d
      @setting  = setting
      @employee = employee
      @month    = month
    end

    def call
      return ZERO_RESULT unless @setting.pt_enabled?
      return ZERO_RESULT unless @employee.pt_applicable?
      return ZERO_RESULT if @setting.pt_state.blank?

      slab = find_slab
      return ZERO_RESULT unless slab

      PtResult.new(
        amount:     slab.tax_amount.to_i,
        state:      @setting.pt_state,
        applicable: true
      )
    end

    private

    def find_slab
      ActsAsTenant.with_tenant(@setting.tenant) do
        # In February, prefer a February-specific row first (Maharashtra special)
        if @month == 2
          feb_slab = ProfessionalTaxSlab
            .where(state: @setting.pt_state, month: "february")
            .where("salary_from <= ? AND salary_to >= ?", @gross, @gross)
            .first
          return feb_slab if feb_slab
        end

        ProfessionalTaxSlab
          .where(state: @setting.pt_state, month: nil)
          .where("salary_from <= ? AND salary_to >= ?", @gross, @gross)
          .first
      end
    end
  end
end
