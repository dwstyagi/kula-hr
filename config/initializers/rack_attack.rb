class Rack::Attack
  # Throttle activation form submissions: 5 per IP per 10 minutes
  throttle("employee_activation/ip", limit: 5, period: 10.minutes) do |req|
    req.ip if req.path.include?("/activate/") && req.post?
  end

  # Throttle login attempts: 10 per IP per 10 minutes
  throttle("logins/ip", limit: 10, period: 10.minutes) do |req|
    req.ip if req.path.include?("/users/sign_in") && req.post?
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
