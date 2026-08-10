require "rails_helper"

RSpec.describe "Search indexing controls", type: :request do
  let(:root_host) { "lvh.me" }

  describe "canonical host" do
    it "permanently redirects www requests to the apex host with path and query intact" do
      get "/pricing?source=google", headers: { "Host" => "www.kula-hr.com" }

      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to eq("http://kula-hr.com/pricing?source=google")
    end
  end

  describe "indexing headers" do
    it "allows the public homepage to be indexed" do
      get root_path, headers: { "Host" => root_host }

      expect(response).to have_http_status(:ok)
      expect(response.headers).not_to include("X-Robots-Tag")
    end

    it "marks signup and the beta guide as noindex" do
      get signup_path, headers: { "Host" => root_host }
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")

      get beta_guide_path, headers: { "Host" => root_host }
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end

    it "marks platform administration as noindex" do
      get platform_admin_login_path, headers: { "Host" => root_host }

      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end

    it "marks tenant authentication and application pages as noindex" do
      tenant = create(:tenant)
      tenant_host = "#{tenant.subdomain}.#{root_host}"

      get new_user_session_path, headers: { "Host" => tenant_host }

      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end
  end

  describe "public discovery files" do
    it "publishes a sitemap containing only indexable public pages" do
      get sitemap_path, headers: { "Host" => root_host }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include("<loc>http://#{root_host}/</loc>")
      expect(response.body).to include("<loc>http://#{root_host}/contact</loc>")
      expect(response.body).to include("<loc>http://#{root_host}/payroll-software-india</loc>")
      expect(response.body).to include("<loc>http://#{root_host}/pricing</loc>")
      expect(response.body).not_to include("/signup")
      expect(response.body).not_to include("/beta-guide")
    end

    it "advertises the canonical sitemap in robots.txt" do
      get "/robots.txt", headers: { "Host" => root_host }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("User-agent: *")
      expect(response.body).to include("Sitemap: https://kula-hr.com/sitemap.xml")
    end
  end

  describe "homepage navigation" do
    it "does not expose the private beta guide" do
      get root_path, headers: { "Host" => root_host }

      expect(response.body).not_to include(beta_guide_path)
      expect(response.body).not_to include("Beta Guide")
    end
  end

  describe "homepage metadata" do
    it "publishes canonical, search, and social metadata" do
      get root_path, headers: { "Host" => root_host }
      document = Nokogiri::HTML(response.body)

      expect(document.at_css("html")["lang"]).to eq("en-IN")
      expect(document.at_css("title").text).to eq("Payroll & HRMS Software for Indian Companies | Kula HR")
      expect(document.at_css('meta[name="description"]')["content"]).to include("Run payroll, attendance, leave")
      expect(document.at_css('link[rel="canonical"]')["href"]).to eq("https://kula-hr.com/")
      expect(document.at_css('meta[property="og:title"]')["content"]).to include("Payroll & HRMS Software")
      expect(document.at_css('meta[property="og:url"]')["content"]).to eq("https://kula-hr.com/")
      expect(document.at_css('meta[name="twitter:card"]')["content"]).to eq("summary")
    end

    it "describes the organization, website, and software product with JSON-LD" do
      get root_path, headers: { "Host" => root_host }
      document = Nokogiri::HTML(response.body)
      structured_data = JSON.parse(document.at_css('script[type="application/ld+json"]').text)

      types = structured_data.fetch("@graph").pluck("@type")
      software = structured_data.fetch("@graph").find { |item| item["@type"] == "SoftwareApplication" }

      expect(types).to contain_exactly("Organization", "WebSite", "SoftwareApplication")
      expect(software.dig("offers", "price")).to eq("99")
      expect(software.dig("offers", "priceCurrency")).to eq("INR")
    end
  end
end
