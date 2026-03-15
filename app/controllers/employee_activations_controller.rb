class EmployeeActivationsController < ApplicationController
  layout "auth"

  skip_before_action :authenticate_user!, raise: false
  skip_after_action  :verify_authorized,  raise: false

  before_action :load_and_validate_token

  def new
  end

  def create
    # Honeypot: bots fill the hidden :website field, humans leave it blank
    unless params[:website].blank?
      redirect_to employee_activation_sent_path(params[:token]) and return
    end

    Employees::SelfActivationService.call(
      tenant:        current_tenant,
      email:         params[:email],
      employee_code: params[:employee_code],
      date_of_birth: params[:date_of_birth]
    )

    # Always redirect to the same generic confirmation — no info leakage
    redirect_to employee_activation_sent_path(params[:token])
  end

  def sent
  end

  private

  def load_and_validate_token
    @tenant = Tenant.find_by(
      subdomain:  request.subdomain,
      activation_token: params[:token]
    )

    unless @tenant&.activation_token_valid?
      render "employee_activations/invalid_token", status: :not_found
    end
  end

  def current_tenant
    @tenant
  end
end
