class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  INDEXABLE_PUBLIC_PATHS = %w[
    /
    /contact
    /payroll-software-india
    /hrms-software-for-small-business
    /leave-management-software
    /attendance-management-software
    /pf-esi-payroll-compliance
    /employee-self-service-portal
    /pricing
    /about
    /security
    /resources
    /resources/payroll-calculators
    /resources/payroll-compliance-calendar
    /resources/payroll-checklist
    /resources/professional-tax-guide
    /privacy-policy
    /terms-of-service
    /sitemap.xml
  ].freeze

  set_current_tenant_through_filter

  allow_browser versions: :modern
  stale_when_importmap_changes

  prepend_before_action :set_search_indexing_header
  before_action :set_current_tenant_from_subdomain
  before_action :verify_tenant_membership!

  after_action :verify_authorized, unless: :skip_authorization_verification?
  after_action :verify_policy_scoped, unless: :skip_policy_scope_verification?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  # Keep production-facing links on the public canonical domain even if an old
  # local or pre-launch APP_DOMAIN value survives in the environment.
  def canonical_app_domain
    return "lvh.me:3000" if Rails.env.development?

    configured = ENV.fetch("APP_DOMAIN", "kula-hr.com")
    return "kula-hr.com" if configured.match?(/\A(?:www\.)?(?:lvh\.me(?::\d+)?|kulahr\.com)\z/i)

    configured
  end

  # The product, authentication, signup, and private testing surfaces are not
  # search landing pages. An HTTP header covers every response format and every
  # layout, including the layout-free beta guide.
  def set_search_indexing_header
    root_domain = request.subdomain.blank?
    public_page = root_domain && INDEXABLE_PUBLIC_PATHS.include?(request.path)

    response.set_header("X-Robots-Tag", "noindex, nofollow") unless public_page
  end

  def set_current_tenant_from_subdomain
    return unless request.subdomain.present? && request.subdomain != "www"

    tenant = Tenant.find_by(subdomain: request.subdomain)
    if tenant.nil?
      redirect_to root_url(subdomain: nil), alert: "Company not found.", allow_other_host: true
    elsif tenant.suspended? && request.path != "/suspended"
      sign_out(current_user) if user_signed_in?
      redirect_to suspended_url
    else
      set_current_tenant(tenant)
    end
  end

  # acts_as_tenant scopes every query to the current tenant, but it does not
  # decide who is allowed to stand inside that tenant. Devise authenticates
  # against the global users table and Rolify roles are not scoped to a tenant,
  # so authentication + role alone would let an admin of one tenant sign in on
  # another tenant's subdomain and read its data. Membership is the missing half
  # of that authorization question, and it is enforced here so every
  # tenant-facing surface inherits it rather than opting in.
  def verify_tenant_membership!
    tenant = ActsAsTenant.current_tenant
    return if tenant.nil? || !user_signed_in?
    return if current_user.member_of?(tenant)

    sign_out(current_user)
    redirect_to new_user_session_path,
                alert: "Your account doesn't have access to this company."
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
