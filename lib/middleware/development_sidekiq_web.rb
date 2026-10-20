require "sidekiq/web"
require "rack/request"

# Browsers omit Fetch Metadata on http://lvh.me. Use an exact Origin check
# for this local development URL instead. Only mounted in development.
class DevelopmentSidekiqWeb < Sidekiq::Web
  LOCAL_ORIGIN = "http://lvh.me:3000".freeze

  def safe_request?(env)
    return true if super
    return false unless env["HTTP_SEC_FETCH_SITE"].nil?

    env["HTTP_ORIGIN"] == LOCAL_ORIGIN &&
      Rack::Request.new(env).base_url == LOCAL_ORIGIN
  end
end
