module Leave
  # Allocates leave balances on joining (first month's quota only).
  # Creates one LeaveBalance per active, paid leave type for the current FY.
  # Skips LOP (unpaid) — it's unlimited and doesn't need a balance record.
  # MonthlyLeaveAccrualService credits subsequent monthly quotas on the 1st of each month.
  class LeaveBalanceAllocator
    def initialize(employee: nil, employees: nil)
      @employees = Array(employee || employees)
      @tenant    = @employees.first&.tenant
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
      records.each do |attributes|
        key = attributes.slice(:employee_id, :leave_type_id, :financial_year)
        LeaveAuditContext.set(reason: "Joining allocation") do
          LeaveBalance.find_or_create_by!(key) { |balance| balance.assign_attributes(attributes) }
        end
      end
    end

    private

    # On joining, employees receive the first month's allocation.
    # Subsequent months are credited automatically by MonthlyLeaveAccrualService.
    def calculate_allocation(leave_type, _employee)
      AccrualAmount.for(leave_type, Date.current)
    end
  end
end
