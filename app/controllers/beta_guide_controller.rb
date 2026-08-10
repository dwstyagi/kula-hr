class BetaGuideController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout false

  def show
    @app_domain = canonical_app_domain
    @platform_url = "#{request.protocol}#{@app_domain}"
    @tenant_url   = "#{request.protocol}[subdomain].#{@app_domain}"
  end
end
