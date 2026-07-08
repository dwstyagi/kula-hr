module Admin
  class DashboardController < BaseController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    # The dashboard is an action center: "what do I need to do before pay day?"
    # Deep-dive analytics (departments, salary ranges, hiring trend) live under
    # Reports, not here.
    def index
      today = Date.current

      @total_employees     = Employee.count
      @active_employees    = Employee.active.count
      @probation_employees = Employee.probation.count

      @on_leave_today = LeaveRequest.where(status: :approved)
                                    .where("from_date <= ? AND to_date >= ?", today, today)
                                    .count

      # ── Needs attention queue ────────────────────────────────────────────
      @missing_bank_count = Employee.active
        .where("bank_account_number IS NULL OR bank_account_number = '' OR ifsc_code IS NULL OR ifsc_code = ''")
        .count

      @missing_salary_count = Employee.active
        .where.not(id: EmployeeSalary.where(effective_to: nil).select(:employee_id))
        .count

      locked = AttendanceSummary.where(month: today.month, year: today.year, status: :locked)
                                .distinct.count(:employee_id)
      @unlocked_attendance_count = [ @active_employees - locked, 0 ].max

      @payroll_data = Dashboard::AdminDashboardService.new(tenant: ActsAsTenant.current_tenant).call

      # ── People moments ───────────────────────────────────────────────────
      @recent_hires = Employee.active.order(joining_date: :desc).limit(5)
      @upcoming_birthdays     = upcoming_by_date(:date_of_birth)
      @upcoming_anniversaries = upcoming_by_date(:joining_date)
    end

    private

    # Employees whose +column+'s month/day falls within the next 30 days.
    def upcoming_by_date(column)
      today    = Date.current
      end_date = today + 30.days

      scope =
        if today.month == end_date.month
          Employee.active.where(
            "EXTRACT(MONTH FROM #{column}) = ? AND EXTRACT(DAY FROM #{column}) BETWEEN ? AND ?",
            today.month, today.day, end_date.day
          )
        else
          Employee.active.where(
            "(EXTRACT(MONTH FROM #{column}) = ? AND EXTRACT(DAY FROM #{column}) >= ?) OR " \
            "(EXTRACT(MONTH FROM #{column}) = ? AND EXTRACT(DAY FROM #{column}) <= ?)",
            today.month, today.day, end_date.month, end_date.day
          )
        end

      scope.order(Arel.sql("EXTRACT(MONTH FROM #{column}), EXTRACT(DAY FROM #{column})")).limit(5)
    end
  end
end
