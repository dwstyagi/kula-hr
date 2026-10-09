class Rack::Attack
  # Throttle activation form submissions: 5 per IP per 10 minutes
  throttle("employee_activation/ip", limit: 5, period: 10.minutes) do |req|
    req.ip if req.path.include?("/activate/") && req.post?
  end

  # Throttle login attempts: 10 per IP per 10 minutes
  throttle("logins/ip", limit: 10, period: 10.minutes) do |req|
    req.ip if req.path.include?("/users/sign_in") && req.post?
  end

  # Per-account login throttle: stops password guessing spread across many
  # IPs against one email. 20 attempts per email per hour.
  throttle("logins/email", limit: 20, period: 1.hour) do |req|
    if req.path.include?("/users/sign_in") && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end

  # Password reset / invitation emails: avoid mail bombing and enumeration.
  throttle("password_resets/ip", limit: 5, period: 15.minutes) do |req|
    req.ip if req.path.start_with?("/users/password") && req.post?
  end

  # Platform admin login controls every tenant: throttle by IP and by email.
  throttle("platform_logins/ip", limit: 5, period: 10.minutes) do |req|
    req.ip if req.path == "/platform_admin/login" && req.post?
  end

  throttle("platform_logins/email", limit: 10, period: 1.hour) do |req|
    req.params["email"].to_s.downcase.strip.presence if req.path == "/platform_admin/login" && req.post?
  end

  # Return 429 with a clear message when throttled
  self.throttled_responder = lambda do |env|
    [
      429,
      { "Content-Type" => "text/plain" },
      [ "Too many requests. Please wait a few minutes and try again." ]
    ]
  end
end
