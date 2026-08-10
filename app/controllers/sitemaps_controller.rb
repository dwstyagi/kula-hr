class SitemapsController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout false

  def show
    url_options = {
      host: ENV.fetch("APP_DOMAIN", request.domain),
      protocol: Rails.env.production? ? "https" : request.protocol
    }

    @urls = [
      root_url(**url_options),
      payroll_software_india_url(**url_options),
      hrms_software_small_business_url(**url_options),
      leave_management_software_url(**url_options),
      attendance_management_software_url(**url_options),
      payroll_compliance_url(**url_options),
      employee_self_service_portal_url(**url_options),
      pricing_url(**url_options),
      about_url(**url_options),
      security_url(**url_options),
      resources_url(**url_options),
      payroll_calculators_url(**url_options),
      payroll_compliance_calendar_url(**url_options),
      payroll_checklist_url(**url_options),
      professional_tax_guide_url(**url_options),
      contact_url(**url_options),
      privacy_policy_url(**url_options),
      terms_of_service_url(**url_options)
    ]

    expires_in 12.hours, public: true
  end
end
