module Leave
  # Debits or credits leave balance when a request is approved or cancelled.
  class LeaveBalanceAdjuster
    InsufficientBalance = Class.new(StandardError)

    def initialize(leave_request:)
      @leave_request = leave_request
      @balance = LeaveBalance.find_by(
        employee:       leave_request.employee,
        leave_type:     leave_request.leave_type,
        financial_year: LeaveBalance.current_financial_year
      )
    end

    # Called on approval — deducts days from remaining balance
    def debit!
      return if @leave_request.leave_type.lop?

      unless @balance
        raise InsufficientBalance, "No balance record found for #{@leave_request.leave_type.name}"
      end

      @balance.with_lock do
        if @balance.remaining_days < @leave_request.number_of_days
          raise InsufficientBalance,
            "Insufficient #{@leave_request.leave_type.name} balance. " \
            "#{@balance.remaining_days} days remaining, #{@leave_request.number_of_days} requested."
        end

        @balance.update!(
          used_days:      @balance.used_days + @leave_request.number_of_days,
          remaining_days: @balance.remaining_days - @leave_request.number_of_days
        )
      end
    end

    # Called on cancellation of an approved request — credits days back
    def credit!
      return if @leave_request.leave_type.lop?
      return unless @balance

      @balance.with_lock do
        @balance.update!(
          used_days:      [ @balance.used_days - @leave_request.number_of_days, 0 ].max,
          remaining_days: @balance.remaining_days + @leave_request.number_of_days
        )
      end
    end
  end
end
