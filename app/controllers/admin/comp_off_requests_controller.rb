module Admin
  class CompOffRequestsController < BaseController
    before_action :set_request, only: [ :approve, :reject ]

    def index
      authorize CompOffRequest
      requests = policy_scope(CompOffRequest)
        .includes(:employee, :approved_by)
        .order(created_at: :desc)

      @status_counts = policy_scope(CompOffRequest).group(:status).count
      requests = requests.where(status: params[:status]) if params[:status].present?
      @pagy, @comp_off_requests = pagy(:offset, requests, limit: 20)
    end

    def approve
      authorize @comp_off_request
      if Leave::CompOffReview.new(request: @comp_off_request, reviewer: current_user).approve!
        redirect_to admin_comp_off_requests_path,
          notice: "Comp-off approved for #{@comp_off_request.employee.full_name}. 1 day credited (expires #{@comp_off_request.expiry_date.strftime('%d %b')})."
      else
        redirect_to admin_comp_off_requests_path, alert: "Only pending requests can be approved."
      end
    end

    def reject
      authorize @comp_off_request
      if Leave::CompOffReview.new(request: @comp_off_request, reviewer: current_user).reject!(reason: params[:rejection_reason])
        redirect_to admin_comp_off_requests_path,
          notice: "Comp-off request rejected for #{@comp_off_request.employee.full_name}."
      else
        redirect_to admin_comp_off_requests_path, alert: "Only pending requests can be rejected."
      end
    end

    private

    def set_request
      @comp_off_request = policy_scope(CompOffRequest).find(params[:id])
    end
  end
end
