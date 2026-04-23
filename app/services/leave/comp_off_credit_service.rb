module Leave
  # Credits 1 comp-off day to the employee's balance on approval.
  # Sets expiry_date = approved_at + 7 days on the request.
  class CompOffCreditService
    EXPIRY_DAYS = 7

    def initialize(comp_off_request:)
      @request  = comp_off_request
      @employee = comp_off_request.employee
    end

    def call
      comp_off_type = LeaveType.find_by!(code: "CO")
      fy            = LeaveBalance.current_financial_year

      balance = LeaveBalance.find_or_initialize_by(
        employee:       @employee,
        leave_type:     comp_off_type,
        financial_year: fy
      )

      if balance.new_record?
        balance.tenant     = @employee.tenant
        balance.total_days = 0
        balance.used_days  = 0
        balance.remaining_days       = 0
        balance.carried_forward_days = 0
      end

      balance.with_lock do
        balance.update!(
          total_days:     balance.total_days + 1,
          remaining_days: balance.remaining_days + 1
        )
      end

      @request.update!(expiry_date: Date.today + EXPIRY_DAYS)
    end
  end
end
