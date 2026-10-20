module Admin
  class LeaveRequestsController < BaseController
    before_action :set_leave_request, only: [ :show, :approve, :reject, :cancel ]
    rescue_from Leave::RequestTransition::Error, Leave::LeaveBalanceAdjuster::InsufficientBalance, with: :transition_failed

    def index
      requests = policy_scope(LeaveRequest)
        .includes(:leave_type, :approved_by, employee: { reporting_manager: :user })
        .order(created_at: :desc)

      @status_counts = policy_scope(LeaveRequest).group(:status).count
      requests = requests.where(status: params[:status]) if params[:status].present?

      @pagy, @leave_requests = pagy(:offset, requests, limit: 20)
    end

    def new
      @leave_request = LeaveRequest.new
      authorize @leave_request
      @leave_types = LeaveType.active.order(:name)
    end

    def create
      @leave_request = LeaveRequest.new(params.require(:leave_request).permit(:leave_type_id, :from_date, :to_date, :duration, :reason, :regularization_note))
      @leave_request.employee = Employee.find_by(employee_code: params[:employee_code].to_s.strip)
      authorize @leave_request
      if @leave_request.save
        Leave::NotificationBroadcaster.new(leave_request: @leave_request).broadcast_new_request!
        redirect_to admin_leave_requests_path, notice: "Leave request submitted for HR review."
      else
        @leave_types = LeaveType.active.order(:name)
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize @leave_request
      render layout: false if turbo_frame_request?
    end

    def bulk_approve
      authorize LeaveRequest, :bulk_approve?
      approved, skipped = 0, []
      policy_scope(LeaveRequest).where(id: params[:ids], status: :pending).find_each do |request|
        unless request.hr_approval_required? && policy(request).approve?
          skipped << "#{request.employee.full_name} (manager approves)"
          next
        end
        begin
          Leave::RequestTransition.new(leave_request: request, actor: current_user).call(:approve)
          Leave::NotificationBroadcaster.new(leave_request: request).broadcast_status_update!
          approved += 1
        rescue Leave::RequestTransition::Error, Leave::LeaveBalanceAdjuster::InsufficientBalance => e
          skipped << "#{request.employee.full_name} (#{e.message})"
        end
      end
      message = "#{approved} leave request#{'s' unless approved == 1} approved."
      message += " Skipped: #{skipped.join(', ')}." if skipped.any?
      redirect_to admin_leave_requests_path(status: params[:status].presence), approved.positive? ? { notice: message } : { alert: message }
    end

    def approve
      authorize @leave_request
      return wrong_approver unless @leave_request.hr_approval_required?

      transition(:approve)
      redirect_to admin_leave_requests_path, notice: "Leave approved for #{@leave_request.employee.full_name}."
    end

    def reject
      authorize @leave_request
      return wrong_approver unless @leave_request.hr_approval_required?

      transition(:reject, reason: params[:rejection_reason])
      redirect_to admin_leave_requests_path, notice: "Leave rejected for #{@leave_request.employee.full_name}."
    end

    def cancel
      authorize @leave_request
      transition(:cancel, reason: params[:reason].presence || "Cancelled directly by HR")
      redirect_to admin_leave_requests_path, notice: "Leave cancelled; any debited balance has been restored."
    end


    private


    def set_leave_request
      @leave_request = policy_scope(LeaveRequest).find(params[:id])
    end

    def transition(action, reason: nil)
      Leave::RequestTransition.new(leave_request: @leave_request, actor: current_user).call(action, reason: reason)
      Leave::NotificationBroadcaster.new(leave_request: @leave_request).broadcast_status_update!
    end

    def transition_failed(error)
      redirect_to admin_leave_requests_path, alert: error.message
    end

    def wrong_approver
      redirect_to admin_leave_requests_path, alert: "#{@leave_request.employee.full_name}'s leave approver is their reporting manager, not HR."
    end
  end
end
