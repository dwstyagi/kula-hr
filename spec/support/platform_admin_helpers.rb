module PlatformAdminHelpers
  def login_as_platform_admin(admin = nil)
    admin ||= create(:platform_admin)
    post platform_admin_login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end

RSpec.configure do |config|
  config.include PlatformAdminHelpers, type: :request
end
