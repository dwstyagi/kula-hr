class SuspendedController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :show
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout "marketing"

  def show
    @tenant = Tenant.find_by(subdomain: request.subdomain)
    redirect_to root_url(subdomain: nil), allow_other_host: true unless @tenant&.suspended?
  end
end
