module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_admin_or_hr!
    before_action :set_pending_leave_count

    layout "admin"

    private

    def verify_admin_or_hr!
      unless current_user.has_role?(:super_admin) || current_user.has_role?(:hr_admin)
        redirect_to employee_portal_root_path, alert: "You are not authorized to access the admin panel."
      end
    end

    def set_pending_leave_count
      @pending_leave_count = LeaveRequest.where(status: "pending").count
    end
  end
end
