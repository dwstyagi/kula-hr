class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  set_current_tenant_through_filter

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_tenant_from_subdomain

  after_action :verify_authorized, unless: :skip_authorization_verification?
  after_action :verify_policy_scoped, unless: :skip_policy_scope_verification?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_current_tenant_from_subdomain
    return unless request.subdomain.present? && request.subdomain != "www"

    tenant = Tenant.find_by(subdomain: request.subdomain)
    if tenant
      set_current_tenant(tenant)
    else
      redirect_to root_url(subdomain: nil), alert: "Company not found.", allow_other_host: true
    end
  end

  def skip_pundit?
    devise_controller? || self.class.to_s.start_with?("Platform::")
  end

  def skip_authorization_verification?
    skip_pundit? || action_name == "index"
  end

  def skip_policy_scope_verification?
    skip_pundit? || action_name != "index"
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back fallback_location: root_path, allow_other_host: true
  end

  def after_sign_in_path_for(resource)
    if resource.has_role?(:super_admin) || resource.has_role?(:hr_admin)
      admin_root_path
    else
      employee_portal_root_path
    end
  end
end
