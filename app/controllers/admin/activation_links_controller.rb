module Admin
  class ActivationLinksController < BaseController
    skip_after_action :verify_authorized

    def generate
      ActsAsTenant.current_tenant.generate_activation_token!
      redirect_to admin_employees_path, notice: "Activation link generated. Share it with your employees."
    end

    def revoke
      ActsAsTenant.current_tenant.revoke_activation_token!
      redirect_to admin_employees_path, notice: "Activation link revoked."
    end
  end
end
