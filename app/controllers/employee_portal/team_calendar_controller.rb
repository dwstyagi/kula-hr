module EmployeePortal
  class TeamCalendarController < BaseController
    # Custom query, not a policy scope.
    skip_after_action :verify_policy_scoped

    def index
      @date  = parse_month
      @month = @date.month
      @year  = @date.year

      @employees = team_members
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

    # "My team": department colleagues; if no department, fall back to peers who
    # share my reporting manager; otherwise just me.
    def team_members
      return Employee.none unless current_employee

      scope =
        if current_employee.department_id
          Employee.where(department_id: current_employee.department_id)
        elsif current_employee.reporting_manager_id
          Employee.where(reporting_manager_id: current_employee.reporting_manager_id)
        else
          Employee.where(id: current_employee.id)
        end

      scope.where(employment_status: %w[active probation notice_period]).order(:first_name)
    end
  end
end
