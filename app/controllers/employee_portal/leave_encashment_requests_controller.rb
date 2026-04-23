module EmployeePortal
  class LeaveEncashmentRequestsController < BaseController
    before_action :ensure_employee!

    skip_after_action :verify_policy_scoped
    skip_after_action :verify_authorized

    def index
      @encashment_requests = LeaveEncashmentRequest
        .where(employee: current_employee)
        .includes(:leave_type, :approved_by)
        .order(created_at: :desc)
    end

    def create
      fy      = LeaveBalance.current_financial_year
      balance = LeaveBalance.find_by(
        employee:       current_employee,
        leave_type_id:  params[:leave_type_id],
        financial_year: fy
      )
      leave_type = LeaveType.find(params[:leave_type_id])
      eligible_days = balance ? [ leave_type.max_carry_forward, balance.remaining_days ].min : 0

      @encashment_request = LeaveEncashmentRequest.new(
        employee:       current_employee,
        leave_type:     leave_type,
        financial_year: fy,
        number_of_days: eligible_days
      )

      if @encashment_request.save
        redirect_to employee_portal_leave_requests_path,
          notice: "Encashment request submitted for #{eligible_days.to_i} #{leave_type.name} day(s). HR will review it shortly."
      else
        redirect_to employee_portal_leave_requests_path,
          alert: @encashment_request.errors.full_messages.to_sentence
      end
    end

    private

    def ensure_employee!
      unless current_employee
        redirect_to employee_portal_root_path,
          alert: "No employee profile found for your account."
      end
    end
  end
end
