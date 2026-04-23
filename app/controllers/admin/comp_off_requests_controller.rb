module Admin
  class CompOffRequestsController < BaseController
    before_action :set_request, only: [ :approve, :reject ]

    def index
      requests = CompOffRequest
        .includes(:employee, :approved_by)
        .order(created_at: :desc)

      requests = requests.where(status: params[:status]) if params[:status].present?
      @pagy, @comp_off_requests = pagy(:offset, requests, limit: 20)
    end

    def approve
      unless @comp_off_request.pending?
        return redirect_to admin_comp_off_requests_path, alert: "Only pending requests can be approved."
      end

      @comp_off_request.update!(
        status:      :approved,
        approved_by: current_user,
        approved_at: Time.current
      )
      Leave::CompOffCreditService.new(comp_off_request: @comp_off_request).call
      notify_employee(:approved)

      redirect_to admin_comp_off_requests_path,
        notice: "Comp-off approved for #{@comp_off_request.employee.full_name}. 1 day credited (expires #{@comp_off_request.expiry_date.strftime('%d %b')})."
    end

    def reject
      unless @comp_off_request.pending?
        return redirect_to admin_comp_off_requests_path, alert: "Only pending requests can be rejected."
      end

      @comp_off_request.update!(
        status:           :rejected,
        rejection_reason: params[:rejection_reason].to_s.strip,
        approved_by:      current_user,
        approved_at:      Time.current
      )
      notify_employee(:rejected)

      redirect_to admin_comp_off_requests_path,
        notice: "Comp-off request rejected for #{@comp_off_request.employee.full_name}."
    end

    private

    def set_request
      @comp_off_request = CompOffRequest.find(params[:id])
    end

    def notify_employee(outcome)
      user = @comp_off_request.employee.user
      return unless user

      if outcome == :approved
        ActionCable.server.broadcast(
          "notifications_user_#{user.id}",
          {
            title:   "Comp-Off Approved",
            message: "Your comp-off for #{@comp_off_request.worked_date.strftime('%d %b %Y')} was approved. 1 day credited — use it before #{@comp_off_request.expiry_date.strftime('%d %b %Y')}.",
            kind:    "success",
            url:     "/portal/comp_off_requests"
          }
        )
      else
        ActionCable.server.broadcast(
          "notifications_user_#{user.id}",
          {
            title:   "Comp-Off Not Approved",
            message: "Your comp-off request for #{@comp_off_request.worked_date.strftime('%d %b %Y')} was not approved.#{@comp_off_request.rejection_reason.present? ? ' Reason: ' + @comp_off_request.rejection_reason : ''}",
            kind:    "error",
            url:     "/portal/comp_off_requests"
          }
        )
      end
    end
  end
end
