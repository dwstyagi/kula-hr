require "rails_helper"

RSpec.describe "Public trust and payroll resources", type: :request do
  let(:root_host) { "lvh.me" }

  pages = {
    "/about" => "About Kula HR | Indian Payroll & HRMS",
    "/security" => "Security & Data Handling | Kula HR",
    "/resources" => "Free Indian Payroll Resources & Calculators | Kula HR",
    "/resources/payroll-calculators" => "Free Indian Payroll Calculators — PF, ESI & CTC | Kula HR",
    "/resources/pf-calculator" => "PF Calculator: Employee & Employer EPF Contribution | Kula HR",
    "/resources/esi-calculator" => "ESI Calculator: Eligibility & Contribution Rates | Kula HR",
    "/resources/ctc-to-in-hand-salary-calculator" => "CTC to In-Hand Salary Calculator (India) | Kula HR",
    "/resources/payroll-compliance-calendar" => "Indian Payroll Compliance Calendar 2026–27 | Kula HR",
    "/resources/payroll-checklist" => "FY 2026–27 Indian Payroll Checklist | Kula HR",
    "/resources/professional-tax-guide" => "State-Wise Professional Tax Guide for Payroll | Kula HR"
  }

  pages.each do |path, expected_title|
    it "renders indexable metadata and useful content for #{path}" do
      get path, headers: { "Host" => root_host }
      document = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:ok)
      expect(response.headers).not_to include("X-Robots-Tag")
      expect(document.at_css("title").text).to eq(expected_title)
      expect(document.at_css('meta[name="description"]')["content"]).to be_present
      expect(document.at_css('link[rel="canonical"]')["href"]).to eq("https://kula-hr.com#{path}")
      expect(document.css("h1").one?).to be(true)

      structured_data = JSON.parse(document.at_css('script[type="application/ld+json"]').text)
      expect(structured_data.fetch("url")).to eq("https://kula-hr.com#{path}")
    end
  end

  it "publishes all trust and resource pages in the sitemap" do
    get sitemap_path, headers: { "Host" => root_host }

    pages.each_key do |path|
      expect(response.body).to include("http://#{root_host}#{path}")
    end
  end

  it "links the verified government sources from the calculators" do
    get payroll_calculators_path, headers: { "Host" => root_host }

    expect(response.body).to include("epfindia.gov.in")
    expect(response.body).to include("esic.gov.in")
    expect(response.body).to include("incometax.gov.in")
    expect(response.body).to include("Last reviewed")
  end

  it "ships the two downloadable workbooks used by the resource library" do
    expect(Rails.root.join("public/downloads/kula-hr-monthly-payroll-template.xlsx")).to exist
    expect(Rails.root.join("public/downloads/kula-hr-monthly-attendance-template.xlsx")).to exist
  end

  it "uses the canonical contact email and a production-safe signup domain" do
    get contact_path, headers: { "Host" => root_host }
    expect(response.body).to include("hello@kula-hr.com")
    expect(response.body).not_to include("hello@kulahr.com")

    get signup_path, headers: { "Host" => root_host }
    expect(response.body).to include(".kula-hr.com")
    expect(response.body).not_to include(".lvh.me")
  end
end
