module EmployeePortal
  class CompOffRequestsController < BaseController
    before_action :ensure_employee!

    skip_after_action :verify_policy_scoped
    skip_after_action :verify_authorized

    def index
      @comp_off_requests = CompOffRequest
        .where(employee: current_employee)
        .order(created_at: :desc)

      @comp_off_balance = LeaveBalance.find_by(
        employee:       current_employee,
        leave_type:     LeaveType.find_by(code: "CO"),
        financial_year: LeaveBalance.current_financial_year
      )
    end

    def new
      @comp_off_request = CompOffRequest.new
    end

    def create
      @comp_off_request = CompOffRequest.new(comp_off_params)
      @comp_off_request.employee = current_employee

      if @comp_off_request.save
        notify_approver
        redirect_to employee_portal_comp_off_requests_path,
          notice: "Comp-off request submitted for #{@comp_off_request.worked_date.strftime('%d %b %Y')}."
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def comp_off_params
      params.require(:comp_off_request).permit(:worked_date, :reason)
    end

    def ensure_employee!
      unless current_employee
        redirect_to employee_portal_root_path,
          alert: "No employee profile found for your account."
      end
    end

    def notify_approver
      approver = current_employee.reporting_manager&.user ||
                 hr_admin_user

      return unless approver

      ActionCable.server.broadcast(
        "notifications_user_#{approver.id}",
        {
          title:   "New Comp-Off Request",
          message: "#{current_employee.full_name} raised a comp-off request for #{@comp_off_request.worked_date.strftime('%d %b %Y')}.",
          kind:    "info",
          url:     current_employee.reporting_manager ? "/portal/team_comp_off_requests" : "/admin/comp_off_requests"
        }
      )
    end

    def hr_admin_user
      TenantUser
        .where(tenant: current_tenant)
        .joins(user: :roles)
        .where(roles: { name: %w[super_admin hr_admin] })
        .includes(:user)
        .first&.user
    end
  end
end
