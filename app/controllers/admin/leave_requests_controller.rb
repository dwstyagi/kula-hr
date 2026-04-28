module Admin
  class LeaveRequestsController < BaseController
    before_action :set_leave_request, only: [ :approve, :reject, :cancel ]

    def index
      requests = policy_scope(LeaveRequest)
        .includes(:leave_type, :approved_by, employee: { reporting_manager: :user })
        .order(created_at: :desc)

      requests = requests.where(status: params[:status]) if params[:status].present?

      @pagy, @leave_requests = pagy(:offset, requests, limit: 20)
    end

    def approve
      authorize @leave_request

      unless @leave_request.employee.hr_is_approver?
        return redirect_to admin_leave_requests_path,
          alert: "#{@leave_request.employee.full_name}'s leave approver is their reporting manager, not HR."
      end

      @leave_request.with_lock do
        unless @leave_request.pending?
          return redirect_to admin_leave_requests_path, alert: "Only pending requests can be approved."
        end
        Leave::LeaveBalanceAdjuster.new(leave_request: @leave_request).debit!
        @leave_request.update!(
          status:      :approved,
          approved_by: current_user,
          approved_at: Time.current
        )
        Leave::NotificationBroadcaster.new(leave_request: @leave_request).broadcast_status_update!
      end
      redirect_to admin_leave_requests_path, notice: "Leave approved for #{@leave_request.employee.full_name}."
    rescue Leave::LeaveBalanceAdjuster::InsufficientBalance => e
      redirect_to admin_leave_requests_path, alert: e.message
    end

    def reject
      authorize @leave_request

      unless @leave_request.employee.hr_is_approver?
        return redirect_to admin_leave_requests_path,
          alert: "#{@leave_request.employee.full_name}'s leave approver is their reporting manager, not HR."
      end

      @leave_request.with_lock do
        unless @leave_request.pending?
          return redirect_to admin_leave_requests_path, alert: "Only pending requests can be rejected."
        end
        @leave_request.update!(
          status:           :rejected,
          rejection_reason: params[:rejection_reason].to_s.strip,
          approved_by:      current_user,
          approved_at:      Time.current
        )
        Leave::NotificationBroadcaster.new(leave_request: @leave_request).broadcast_status_update!
      end
      redirect_to admin_leave_requests_path, notice: "Leave rejected for #{@leave_request.employee.full_name}."
    end

    def cancel
      authorize @leave_request

      if @leave_request.to_date < Date.today
        return redirect_to admin_leave_requests_path, alert: "Cannot cancel a leave whose dates have already passed."
      end

      @leave_request.with_lock do
        if @leave_request.approved?
          Leave::LeaveBalanceAdjuster.new(leave_request: @leave_request).credit!
          @leave_request.update!(status: :cancelled)
          return redirect_to admin_leave_requests_path, notice: "Approved leave cancelled and balance restored."
        elsif @leave_request.pending?
          @leave_request.update!(status: :cancelled)
          return redirect_to admin_leave_requests_path, notice: "Leave request cancelled."
        else
          return redirect_to admin_leave_requests_path, alert: "This request cannot be cancelled."
        end
      end
    end

    private

    def set_leave_request
      @leave_request = LeaveRequest.find(params[:id])
    end
  end
end
