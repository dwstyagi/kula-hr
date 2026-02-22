module DeviseHelpers
  def sign_in_as(user)
    post user_session_path,
         params: { user: { email: user.email, password: "password123" } },
         headers: { "Host" => "#{ActsAsTenant.current_tenant.subdomain}.lvh.me" }
  end
end

RSpec.configure do |config|
  config.include DeviseHelpers, type: :request
end
