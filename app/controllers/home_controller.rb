class HomeController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout "marketing"

  def index
    @app_domain = Rails.env.development? ? "lvh.me:3000" : ENV.fetch("APP_DOMAIN", "kulahr.com")
  end

  def check_tenant
    subdomain = params[:subdomain].to_s.strip.downcase
    exists = subdomain.present? && Tenant.exists?(subdomain: subdomain, status: [ :trial, :active ])
    render json: { exists: exists }
  end
end
