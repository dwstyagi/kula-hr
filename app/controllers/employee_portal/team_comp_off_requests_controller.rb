module EmployeePortal
  class TeamCompOffRequestsController < BaseController
    before_action :ensure_manager!
    before_action :set_request, only: [ :approve, :reject ]

    skip_after_action :verify_policy_scoped

    def index
      @comp_off_requests = CompOffRequest
        .where(employee: current_employee.direct_reports)
        .includes(:employee, :approved_by)
        .order(created_at: :desc)

      @comp_off_requests = @comp_off_requests.where(status: params[:status]) if params[:status].present?
    end

    def approve
      authorize @comp_off_request
      if Leave::CompOffReview.new(request: @comp_off_request, reviewer: current_user).approve!
        redirect_to employee_portal_team_comp_off_requests_path,
          notice: "Comp-off approved for #{@comp_off_request.employee.full_name}. 1 day credited (expires #{@comp_off_request.expiry_date.strftime('%d %b')})."
      else
        redirect_to employee_portal_team_comp_off_requests_path, alert: "Only pending requests can be approved."
      end
    end

    def reject
      authorize @comp_off_request
      if Leave::CompOffReview.new(request: @comp_off_request, reviewer: current_user).reject!(reason: params[:rejection_reason])
        redirect_to employee_portal_team_comp_off_requests_path,
          notice: "Comp-off request rejected for #{@comp_off_request.employee.full_name}."
      else
        redirect_to employee_portal_team_comp_off_requests_path, alert: "Only pending requests can be rejected."
      end
    end

    private

    def ensure_manager!
      unless current_employee&.direct_reports&.exists?
        redirect_to employee_portal_root_path, alert: "You do not have any direct reports."
      end
    end

    def set_request
      @comp_off_request = CompOffRequest
        .where(employee: current_employee.direct_reports)
        .find(params[:id])
    end
  end
end
