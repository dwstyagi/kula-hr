require "spec_helper"
require "rack/mock"
require_relative "../../lib/middleware/development_sidekiq_web"

RSpec.describe DevelopmentSidekiqWeb do
  let(:web) { described_class.new }

  def request_env(origin: "http://lvh.me:3000", url: "http://lvh.me:3000/platform_admin/sidekiq/retries", fetch_site: nil)
    env = Rack::MockRequest.env_for(url, method: "POST")
    env["HTTP_ORIGIN"] = origin if origin
    env["HTTP_SEC_FETCH_SITE"] = fetch_site if fetch_site
    env
  end

  it "allows local retry actions without Fetch Metadata when the Origin matches" do
    expect(web.safe_request?(request_env)).to be(true)
  end

  it "preserves normal Sidekiq protection for secure same-origin requests" do
    env = request_env(origin: "https://kula-hr.com", url: "https://kula-hr.com/platform_admin/sidekiq/retries", fetch_site: "same-origin")
    expect(web.safe_request?(env)).to be(true)
  end

  it "rejects missing Origin when Fetch Metadata is absent" do
    expect(web.safe_request?(request_env(origin: nil))).to be(false)
  end

  it "rejects an external Origin" do
    expect(web.safe_request?(request_env(origin: "https://example.com"))).to be(false)
  end

  it "rejects another tenant subdomain" do
    expect(web.safe_request?(request_env(origin: "http://acme.lvh.me:3000"))).to be(false)
  end

  it "rejects another port" do
    expect(web.safe_request?(request_env(origin: "http://lvh.me:4000"))).to be(false)
  end

  it "does not override explicit cross-site Fetch Metadata" do
    expect(web.safe_request?(request_env(fetch_site: "cross-site"))).to be(false)
  end

  it "does not apply the local Origin exception to a production destination" do
    expect(web.safe_request?(request_env(url: "https://kula-hr.com/platform_admin/sidekiq/retries"))).to be(false)
  end

  it "returns Forbidden before reaching job handling for an untrusted request" do
    expect(web).not_to receive(:app)
    expect(web.call(request_env(origin: "https://example.com")).first).to eq(403)
  end

  it "leaves the unmodified Sidekiq app strict for requests without Fetch Metadata" do
    expect(Sidekiq::Web.new.safe_request?(request_env)).to be(false)
  end
end
