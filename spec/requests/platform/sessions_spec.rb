require "rails_helper"

RSpec.describe "Platform::Sessions", type: :request do
  let!(:admin) { create(:platform_admin, email: "admin@kulahr.com", password: "password123", password_confirmation: "password123") }

  describe "GET /platform_admin/login" do
    it "renders the login page" do
      get platform_admin_login_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /platform_admin/login" do
    context "with valid credentials" do
      it "logs in and redirects to dashboard" do
        post platform_admin_login_path, params: { email: "admin@kulahr.com", password: "password123" }
        expect(response).to redirect_to(platform_admin_root_path)
        follow_redirect!
        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid credentials" do
      it "re-renders login with error" do
        post platform_admin_login_path, params: { email: "admin@kulahr.com", password: "wrong" }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "shows error for non-existent email" do
        post platform_admin_login_path, params: { email: "nobody@kulahr.com", password: "password123" }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /platform_admin/logout" do
    it "logs out and redirects to login" do
      login_as_platform_admin(admin)
      delete platform_admin_logout_path
      expect(response).to redirect_to(platform_admin_login_path)
    end
  end
end
