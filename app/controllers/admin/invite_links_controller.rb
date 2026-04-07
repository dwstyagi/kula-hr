module Admin
  class InviteLinksController < BaseController
    skip_after_action :verify_authorized

    def generate
      ActsAsTenant.current_tenant.generate_invite_token!
      redirect_to admin_employees_path, notice: "Invite link generated. Share it with your new hires."
    end

    def revoke
      ActsAsTenant.current_tenant.revoke_invite_token!
      redirect_to admin_employees_path, notice: "Invite link revoked."
    end
  end
end
