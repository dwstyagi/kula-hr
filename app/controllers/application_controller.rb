class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_tenant_from_subdomain

  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_current_tenant_from_subdomain
    return unless request.subdomain.present? && request.subdomain != "www"

    tenant = Tenant.find_by(subdomain: request.subdomain)
    if tenant
      set_current_tenant(tenant)
    else
      redirect_to root_url(subdomain: nil), alert: "Company not found."
    end
  end

  def skip_pundit?
    devise_controller? || self.class.to_s.start_with?("Platform::")
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back fallback_location: root_path
  end

  def after_sign_in_path_for(resource)
    if resource.has_role?(:super_admin) || resource.has_role?(:hr_admin)
      admin_root_path
    else
      employee_portal_root_path
    end
  end
end
