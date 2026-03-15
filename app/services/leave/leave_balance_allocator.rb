module Leave
  # Allocates leave balances on joining.
  # Creates one LeaveBalance per active, paid leave type for the current FY.
  # Skips LOP (unpaid) — it's unlimited and doesn't need a balance record.
  # Pro-rates allocation based on joining month if payroll_setting.pro_rate_leaves is true.
  class LeaveBalanceAllocator
    def initialize(employee: nil, employees: nil)
      @employees = Array(employee || employees)
      @tenant    = @employees.first.tenant
      @setting   = @tenant.payroll_setting
    end

    def call
      return if @employees.empty?

      financial_year = LeaveBalance.current_financial_year
      leave_types    = LeaveType.active.paid.to_a
      now            = Time.current

      records = @employees.flat_map do |employee|
        leave_types.map do |leave_type|
          allocated = calculate_allocation(leave_type, employee)
          {
            tenant_id:             @tenant.id,
            employee_id:           employee.id,
            leave_type_id:         leave_type.id,
            financial_year:        financial_year,
            total_days:            allocated,
            remaining_days:        allocated,
            used_days:             0,
            carried_forward_days:  0,
            created_at:            now,
            updated_at:            now
          }
        end
      end

      # skip_duplicates: existing balances (e.g. re-imports) are left untouched
      LeaveBalance.insert_all(records, unique_by: %i[employee_id leave_type_id financial_year]) if records.any?
    end

    private

    def calculate_allocation(leave_type, employee)
      return leave_type.annual_quota unless @setting&.pro_rate_leaves?

      months = months_remaining_in_fy(employee.joining_date)
      (leave_type.annual_quota * months / 12.0).ceil
    end

    def months_remaining_in_fy(date)
      fy_end = date.month >= 4 ? Date.new(date.year + 1, 3, 31) : Date.new(date.year, 3, 31)
      (fy_end.year * 12 + fy_end.month) - (date.year * 12 + date.month) + 1
    end
  end
end
