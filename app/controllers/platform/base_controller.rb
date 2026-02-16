module Platform
  class BaseController < ApplicationController
    skip_before_action :set_current_tenant_from_subdomain
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :authenticate_platform_admin!

    layout "platform_admin"

    private

    def authenticate_platform_admin!
      unless current_platform_admin
        redirect_to platform_admin_login_path, alert: "Please log in to continue."
      end
    end

    def current_platform_admin
      @current_platform_admin ||= PlatformAdmin.find_by(id: session[:platform_admin_id])
    end
    helper_method :current_platform_admin
  end
end
