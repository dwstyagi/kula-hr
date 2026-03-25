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
      @leave_requests = @leave_requests.where(status: params[:status]) if params[:status].present?
    end

    def approve
      authorize @leave_request

      unless @leave_request.pending?
        return redirect_to employee_portal_team_leave_requests_path, alert: "Only pending requests can be approved."
      end

      ActiveRecord::Base.transaction do
        Leave::LeaveBalanceAdjuster.new(leave_request: @leave_request).debit!
        @leave_request.update!(
          status:      :approved,
          approved_by: current_user,
          approved_at: Time.current
        )
        Leave::NotificationBroadcaster.new(leave_request: @leave_request).broadcast_status_update!(notify_hr: true)
      end
      redirect_to employee_portal_team_leave_requests_path,
        notice: "Leave approved for #{@leave_request.employee.full_name}."
    rescue Leave::LeaveBalanceAdjuster::InsufficientBalance => e
      redirect_to employee_portal_team_leave_requests_path, alert: e.message
    end

    def reject
      authorize @leave_request

      unless @leave_request.pending?
        return redirect_to employee_portal_team_leave_requests_path, alert: "Only pending requests can be rejected."
      end

      @leave_request.update!(
        status:           :rejected,
        rejection_reason: params[:rejection_reason].to_s.strip,
        approved_by:      current_user,
        approved_at:      Time.current
      )
      Leave::NotificationBroadcaster.new(leave_request: @leave_request).broadcast_status_update!(notify_hr: true)
      redirect_to employee_portal_team_leave_requests_path,
        notice: "Leave rejected for #{@leave_request.employee.full_name}."
    end

    private

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
