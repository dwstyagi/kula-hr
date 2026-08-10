require "rails_helper"

RSpec.describe "Marketing landing pages", type: :request do
  let(:root_host) { "lvh.me" }

  pages = {
    "/payroll-software-india" => "Payroll Software for Indian Companies | Kula HR",
    "/hrms-software-for-small-business" => "HRMS Software for Small Businesses in India | Kula HR",
    "/leave-management-software" => "Leave Management Software for Indian Teams | Kula HR",
    "/attendance-management-software" => "Attendance Management Software for India | Kula HR",
    "/pf-esi-payroll-compliance" => "PF & ESI Payroll Compliance Software | Kula HR",
    "/employee-self-service-portal" => "Employee Self-Service Portal Software | Kula HR",
    "/pricing" => "Kula HR Pricing — ₹99 per Employee per Month"
  }

  pages.each do |path, expected_title|
    it "renders indexable, canonical metadata and original content for #{path}" do
      get path, headers: { "Host" => root_host }
      document = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:ok)
      expect(response.headers).not_to include("X-Robots-Tag")
      expect(document.at_css("title").text).to eq(expected_title)
      expect(document.at_css('meta[name="description"]')["content"]).to be_present
      expect(document.at_css('link[rel="canonical"]')["href"]).to eq("https://kula-hr.com#{path}")
      expect(document.css("h1").one?).to be(true)
      expect(document.css("h2").length).to be >= 5
      expect(document.css("main details").length).to eq(4)

      structured_data = JSON.parse(document.at_css('script[type="application/ld+json"]').text)
      expect(structured_data.fetch("@graph").pluck("@type")).to include("WebPage", "BreadcrumbList", "FAQPage")
    end
  end

  it "links every landing page from the homepage" do
    get root_path, headers: { "Host" => root_host }

    pages.each_key do |path|
      expect(response.body).to include(%(href="#{path}"))
    end
  end

  it "includes every landing page in the public sitemap" do
    get sitemap_path, headers: { "Host" => root_host }

    pages.each_key do |path|
      expect(response.body).to include("http://#{root_host}#{path}")
    end
  end
end
