class SignupsController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout "marketing"

  def new
    @signup_form = SignupForm.new
  end

  def create
    @signup_form = SignupForm.new(signup_params)

    if @signup_form.valid?
      result = Tenants::TenantOnboarder.call(@signup_form)

      if result.success?
        redirect_to new_user_session_url(subdomain: result.tenant.subdomain),
                    notice: "Company registered successfully! Please log in."
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.require(:signup_form).permit(
      :company_name, :subdomain, :first_name, :last_name,
      :email, :password, :password_confirmation, :state
    )
  end
end
