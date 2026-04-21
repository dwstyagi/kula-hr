class BetaFeedbacksController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def create
    type    = params[:feedback_type].to_s.strip
    name    = params[:name].to_s.strip
    email   = params[:email].to_s.strip
    message = params[:message].to_s.strip

    if name.blank? || email.blank? || message.blank?
      render json: { error: "Please fill in all required fields." }, status: :unprocessable_entity
      return
    end

    BetaFeedbackMailer.submission(
      type:     type,
      name:     name,
      email:    email,
      message:  message,
      flow:     params[:flow].to_s.strip,
      step:     params[:step].to_s.strip,
      expected: params[:expected].to_s.strip,
      actual:   params[:actual].to_s.strip,
      browser:  params[:browser].to_s.strip
    ).deliver_later

    render json: { success: true }
  end
end
