module Admin
  class LeaveEncashmentRequestsController < BaseController
    before_action :set_request, only: [ :approve, :reject ]

    def index
      requests = LeaveEncashmentRequest
        .includes(:employee, :leave_type, :approved_by)
        .order(created_at: :desc)

      requests = requests.where(status: params[:status]) if params[:status].present?
      @pagy, @encashment_requests = pagy(:offset, requests, limit: 20)
    end

    def approve
      if @encashment_request.pending?
        begin
          amount = Leave::EncashmentCalculator.new(
            employee:       @encashment_request.employee,
            number_of_days: @encashment_request.number_of_days
          ).call

          @encashment_request.update!(
            status:            :approved,
            encashment_amount: amount,
            approved_by:       current_user,
            approved_at:       Time.current
          )
          notify_employee(:approved)
          redirect_to admin_leave_encashment_requests_path,
            notice: "Encashment approved for #{@encashment_request.employee.full_name}. Amount: ₹#{amount}."
        rescue Leave::EncashmentCalculator::NoSalaryError => e
          redirect_to admin_leave_encashment_requests_path, alert: e.message
        end
      else
        redirect_to admin_leave_encashment_requests_path,
          alert: "Only pending requests can be approved."
      end
    end

    def reject
      if @encashment_request.pending?
        @encashment_request.update!(
          status:           :rejected,
          rejection_reason: params[:rejection_reason].to_s.strip,
          approved_by:      current_user,
          approved_at:      Time.current
        )
        notify_employee(:rejected)
        redirect_to admin_leave_encashment_requests_path,
          notice: "Encashment request rejected for #{@encashment_request.employee.full_name}."
      else
        redirect_to admin_leave_encashment_requests_path,
          alert: "Only pending requests can be rejected."
      end
    end

    private

    def set_request
      @encashment_request = LeaveEncashmentRequest.find(params[:id])
    end

    def notify_employee(outcome)
      employee = @encashment_request.employee
      return unless employee.user

      if outcome == :approved
        LeaveMailer.encashment_approved(@encashment_request).deliver_later
        ActionCable.server.broadcast(
          "notifications_user_#{employee.user.id}",
          {
            title:   "Leave Encashment Approved",
            message: "Your #{@encashment_request.leave_type.name} encashment of #{@encashment_request.number_of_days.to_i} day(s) was approved. ₹#{number_with_delimiter(@encashment_request.encashment_amount.to_i)} will be added to your next payroll.",
            kind:    "success",
            url:     "/portal/leave_requests"
          }
        )
      else
        LeaveMailer.encashment_rejected(@encashment_request).deliver_later
        ActionCable.server.broadcast(
          "notifications_user_#{employee.user.id}",
          {
            title:   "Leave Encashment Not Approved",
            message: "Your #{@encashment_request.leave_type.name} encashment request was not approved. Your days will carry forward to the next year.",
            kind:    "error",
            url:     "/portal/leave_requests"
          }
        )
      end
    end
  end
end
