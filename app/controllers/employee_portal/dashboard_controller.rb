module EmployeePortal
  class DashboardController < BaseController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      return unless current_employee

      @leave_balances   = current_employee.leave_balances
                            .current
                            .includes(:leave_type)
                            .order("leave_types.name")

      @pending_requests = current_employee.leave_requests
                            .pending_approval
                            .includes(:leave_type)
                            .order(created_at: :desc)
                            .limit(3)

      @recent_requests  = current_employee.leave_requests
                            .includes(:leave_type, :approved_by)
                            .order(created_at: :desc)
                            .limit(5)

      today  = Date.today
      @working_days_this_month = Attendance::WorkingDaysCalculator.new(
        month:  today.month,
        year:   today.year,
        tenant: ActsAsTenant.current_tenant
      ).call
    end
  end
end
