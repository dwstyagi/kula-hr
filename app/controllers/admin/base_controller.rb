module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_admin_or_hr!
    before_action :set_pending_leave_count
    before_action :verify_tenant_write_access!, unless: -> { action_name.in?(%w[index show bank_file export template progress]) }

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

    def verify_tenant_write_access!
      tenant = ActsAsTenant.current_tenant
      return if tenant.nil? || tenant.write_allowed?
      msg = if tenant.trial?
        "Your trial has ended — #{ActionController::Base.helpers.pluralize(Tenant::TRIAL_PAYROLL_RUN_LIMIT, 'payroll run')} completed. Upgrade to continue."
      else
        "Your account is #{tenant.status}. Contact support to restore access."
      end
      redirect_to admin_root_path, alert: msg
    end
  end
end
