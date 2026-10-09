module Platform
  class BaseController < ApplicationController
    skip_before_action :set_current_tenant_from_subdomain
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :authenticate_platform_admin!

    layout "platform_admin"

    private

    # Platform admins can act on every tenant, so their sessions expire after
    # a period of inactivity.
    IDLE_TIMEOUT = 30.minutes

    def authenticate_platform_admin!
      seen_at = session[:platform_admin_seen_at].to_i
      if current_platform_admin && Time.current.to_i - seen_at <= IDLE_TIMEOUT.to_i
        session[:platform_admin_seen_at] = Time.current.to_i
        return
      end

      reset_session if session[:platform_admin_id]
      @current_platform_admin = nil
      redirect_to platform_admin_login_path, alert: "Please log in to continue."
    end

    def current_platform_admin
      @current_platform_admin ||= PlatformAdmin.find_by(id: session[:platform_admin_id])
    end
    helper_method :current_platform_admin
  end
end
