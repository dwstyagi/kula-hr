module EmployeePortal
  class LeaveRequestsController < BaseController
    before_action :ensure_employee!
    before_action :set_leave_request, only: [ :cancel ]

    skip_after_action :verify_policy_scoped, only: [ :new, :create, :cancel ]

    def index
      @leave_requests = policy_scope(LeaveRequest)
        .includes(:leave_type)
        .order(created_at: :desc)
      @leave_balances = current_employee.leave_balances.current.includes(:leave_type).order("leave_types.name")
      skip_authorization
    end

    def new
      @leave_request = LeaveRequest.new
      authorize @leave_request
      load_form_data
    end

    def create
      @leave_request = LeaveRequest.new(leave_request_params)
      @leave_request.employee = current_employee
      authorize @leave_request

      if @leave_request.save
        Leave::NotificationBroadcaster.new(leave_request: @leave_request).broadcast_new_request!
        redirect_to employee_portal_leave_requests_path,
          notice: "Leave request submitted successfully."
      else
        load_form_data
        render :new, status: :unprocessable_content
      end
    end

    def cancel
      authorize @leave_request

      if @leave_request.pending?
        @leave_request.update!(status: :cancelled)
        redirect_to employee_portal_leave_requests_path, notice: "Leave request cancelled."
      else
        redirect_to employee_portal_leave_requests_path,
          alert: "Only pending requests can be cancelled."
      end
    end

    private

    def set_leave_request
      @leave_request = LeaveRequest.find_by!(id: params[:id], employee: current_employee)
    end

    def ensure_employee!
      unless current_employee
        redirect_to employee_portal_root_path,
          alert: "No employee profile found for your account."
      end
    end

    def load_form_data
      @leave_types  = LeaveType.active.order(:name)
      @leave_balances = current_employee.leave_balances.current.includes(:leave_type)
    end

    def leave_request_params
      params.require(:leave_request).permit(:leave_type_id, :from_date, :to_date, :reason)
    end
  end
end
