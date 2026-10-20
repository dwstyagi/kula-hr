module EmployeePortal
  class TeamLeaveRequestsController < BaseController
    before_action :ensure_manager!
    before_action :set_leave_request, only: [ :approve, :reject ]

    # index uses a direct query instead of policy_scope
    skip_after_action :verify_policy_scoped

    def index
      @leave_requests = LeaveRequest
        .where(employee: current_employee.direct_reports)
        .includes(:employee, :leave_type, :approved_by)
        .order(created_at: :desc)
      @leave_requests = @leave_requests.where(status: params[:status]) if LeaveRequest.statuses.key?(params[:status])
    end

    def approve
      review(:approve)
    end

    def reject
      review(:reject)
    end

    private

    def review(action)
      authorize @leave_request, "#{action}?"
      if @leave_request.hr_approval_required?
        return redirect_to employee_portal_team_leave_requests_path, alert: "This request requires HR approval."
      end
      Leave::RequestTransition.new(leave_request: @leave_request, actor: current_user)
        .call(action, reason: params[:rejection_reason])
      Leave::NotificationBroadcaster.new(leave_request: @leave_request).broadcast_status_update!(notify_hr: true)
      redirect_to employee_portal_team_leave_requests_path, notice: "Leave #{action == :approve ? 'approved' : 'rejected'}."
    rescue Leave::RequestTransition::Error, Leave::LeaveBalanceAdjuster::InsufficientBalance => e
      redirect_to employee_portal_team_leave_requests_path, alert: e.message
    end

    def ensure_manager!
      unless current_employee&.direct_reports&.exists?
        redirect_to employee_portal_root_path, alert: "You do not have any direct reports."
      end
    end

    def set_leave_request
      # Scope to direct_reports only — RecordNotFound (404) on cross-team ID attempts
      @leave_request = LeaveRequest
        .where(employee: current_employee.direct_reports)
        .find(params[:id])
    end
  end
end
