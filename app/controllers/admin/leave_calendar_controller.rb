module Admin
  class LeaveCalendarController < BaseController
    # Custom query, not a policy scope.
    skip_after_action :verify_policy_scoped

    def index
      @date  = parse_month
      @month = @date.month
      @year  = @date.year

      @departments            = Department.order(:name)
      @selected_department_id = params[:department_id].presence

      @employees = employees_scope
      @calendar  = Leave::TeamCalendar.new(
        employees: @employees, month: @month, year: @year, tenant: ActsAsTenant.current_tenant
      )
    end

    private

    def parse_month
      Date.new(params[:year].to_i, params[:month].to_i, 1)
    rescue ArgumentError, TypeError
      Date.today.beginning_of_month
    end

    def employees_scope
      scope = Employee.where(employment_status: %w[active probation notice_period])
      scope = scope.where(department_id: @selected_department_id) if @selected_department_id
      scope.order(:first_name)
    end
  end
end
