module Platform
  class SessionsController < ApplicationController
    skip_before_action :set_current_tenant_from_subdomain
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    layout "marketing"

    def new
    end

    def create
      admin = PlatformAdmin.find_by(email: params[:email]&.downcase&.strip)

      if admin&.authenticate(params[:password])
        session[:platform_admin_id] = admin.id
        redirect_to platform_admin_root_path, notice: "Logged in successfully."
      else
        flash.now[:alert] = "Invalid email or password."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session.delete(:platform_admin_id)
      redirect_to platform_admin_login_path, notice: "Logged out successfully."
    end
  end
end
