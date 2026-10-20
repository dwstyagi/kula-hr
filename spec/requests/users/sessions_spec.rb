require "rails_helper"

RSpec.describe "Tenant user logout", type: :request do
  let(:tenant) { create(:tenant, :active) }
  let(:host) { { "Host" => "#{tenant.subdomain}.lvh.me" } }

  [ :employee, :hr_admin, :super_admin ].each do |role|
    it "signs out #{role} directly to login with a success message" do
      set_tenant(tenant)
      host! "#{tenant.subdomain}.lvh.me"
      user = create(:user, role)
      create(:tenant_user, tenant: tenant, user: user)
      create(:employee, tenant: tenant, user: user) if role == :employee
      sign_in_as(user)

      delete destroy_user_session_path, headers: host

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("devise.sessions.signed_out"))
      expect(response.body).not_to include(I18n.t("devise.failure.unauthenticated"))

      get(role == :employee ? employee_portal_root_path : admin_root_path, headers: host)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
