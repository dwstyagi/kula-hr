require "uri"

class DevelopmentHostRedirect
  LOCAL_HOSTS = %w[localhost 127.0.0.1 0.0.0.0].freeze
  TARGET_HOST = "lvh.me"

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    return @app.call(env) unless LOCAL_HOSTS.include?(request.host)

    location = URI.parse(request.original_url)
    location.host = TARGET_HOST

    [
      308,
      {
        "location" => location.to_s,
        "content-type" => "text/html; charset=utf-8"
      },
      [ "Redirecting to #{location}" ]
    ]
  end
end
