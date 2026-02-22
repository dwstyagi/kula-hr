module Leave
  # Allocates leave balances for an employee on joining.
  # Creates one LeaveBalance per active, paid leave type for the current FY.
  # Skips LOP (unpaid) — it's unlimited and doesn't need a balance record.
  # Pro-rates allocation based on joining month if payroll_setting.pro_rate_leaves is true.
  class LeaveBalanceAllocator
    def initialize(employee:)
      @employee = employee
      @tenant   = employee.tenant
      @setting  = @tenant.payroll_setting
    end

    def call
      financial_year = LeaveBalance.current_financial_year

      LeaveType.active.paid.each do |leave_type|
        allocated = calculate_allocation(leave_type)

        LeaveBalance.find_or_create_by!(
          tenant:       @tenant,
          employee:     @employee,
          leave_type:   leave_type,
          financial_year: financial_year
        ) do |bal|
          bal.total_days     = allocated
          bal.remaining_days = allocated
          bal.used_days      = 0
          bal.carried_forward_days = 0
        end
      end
    end

    private

    def calculate_allocation(leave_type)
      return leave_type.annual_quota unless @setting&.pro_rate_leaves?

      months = months_remaining_in_fy(@employee.joining_date)
      (leave_type.annual_quota * months / 12.0).ceil
    end

    def months_remaining_in_fy(date)
      fy_end = if date.month >= 4
        Date.new(date.year + 1, 3, 31)
      else
        Date.new(date.year, 3, 31)
      end

      # Number of full months from joining month through end of FY (inclusive)
      (fy_end.year * 12 + fy_end.month) - (date.year * 12 + date.month) + 1
    end
  end
end
