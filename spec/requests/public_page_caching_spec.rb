require "rails_helper"

RSpec.describe "Public page fragment caching", type: :request do
  let(:fragment_store) { ActiveSupport::Cache::MemoryStore.new }
  let(:cache_reads) { [] }

  before do
    allow_any_instance_of(ActionController::Base).to receive(:perform_caching).and_return(true)
    allow_any_instance_of(ActionController::Base).to receive(:cache_store).and_return(fragment_store)
  end

  around do |example|
    subscriber = ->(*args) { cache_reads << ActiveSupport::Notifications::Event.new(*args).payload }
    ActiveSupport::Notifications.subscribed(subscriber, "cache_read.active_support") { example.run }
  end

  def public_cache_hits
    cache_reads.select { |event| event[:hit] && event[:key].to_s.include?("public-pages") }
  end

  paths = %w[
    / /payroll-software-india /hrms-software-for-small-business
    /leave-management-software /attendance-management-software
    /pf-esi-payroll-compliance /employee-self-service-portal /pricing
    /about /security /privacy-policy /terms-of-service
    /resources /resources/payroll-calculators /resources/pf-calculator
    /resources/esi-calculator /resources/ctc-to-in-hand-salary-calculator
    /resources/payroll-compliance-calendar /resources/payroll-checklist
    /resources/professional-tax-guide /blog /blog/payroll-processing-india
  ]

  paths.each do |path|
    it "reuses the body for #{path} while keeping page metadata on cache hits" do
      get path
      expect(response).to have_http_status(:ok)
      first = Nokogiri::HTML(response.body)
      title = first.at_css("title").text
      schemas = first.css('script[type="application/ld+json"]').map(&:text)
      expect(title).to be_present
      cache_reads.clear

      get path
      second = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:ok)
      expect(public_cache_hits).not_to be_empty
      expect(second.at_css("title").text).to eq(title)
      expect(second.css('script[type="application/ld+json"]').map(&:text)).to eq(schemas)
      expect(second.css("h1").map(&:text)).to eq(first.css("h1").map(&:text))
    end
  end

  it "invalidates marketing content when controller-defined copy changes" do
    get "/pricing"
    pages = MarketingPagesController::PAGES.deep_dup
    pages.fetch("pricing")[:headline] = "Updated pricing headline"
    stub_const("MarketingPagesController::PAGES", pages)

    get "/pricing"
    expect(Nokogiri::HTML(response.body).at_css("h1").text).to include("Updated pricing headline")
  end

  it "separates links for applications mounted under a different path" do
    get "/pricing"
    get "/pricing", env: { "SCRIPT_NAME" => "/hrms" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="/hrms/signup"')
  end

  it "refreshes the blog list and related articles when a scheduled post becomes public" do
    today = Date.new(2026, 10, 19)
    upcoming = BlogPost.new(slug: "scheduled-cache-guide", meta: {
      "title" => "A newly published cache guide", "description" => "Scheduled guide",
      "summary" => "Scheduled guide", "published_on" => today + 1
    }, markdown: "## Scheduled guide\nNew content")
    allow(BlogPost).to receive(:all).and_return([ upcoming ] + BlogPost.all)

    travel_to today.noon do
      get "/blog"
      expect(response.body).not_to include(upcoming.path)
      get "/blog/payroll-processing-india"
      expect(response.body).not_to include(upcoming.path)
    end

    travel_to (today + 1).noon do
      get "/blog"
      expect(response.body).to include(upcoming.path)
      get "/blog/payroll-processing-india"
      expect(response.body).to include(upcoming.path)
      get upcoming.path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New content")
    end
  end

  it "refreshes blog content even when its editorial update date is unchanged" do
    original = BlogPost.find("payroll-processing-india")
    allow(BlogPost).to receive(:all).and_return([ original ])
    get original.path

    edited = BlogPost.new(slug: original.slug, meta: {
      "title" => original.title, "description" => original.description,
      "summary" => original.summary, "published_on" => original.published_on,
      "updated_on" => original.updated_on
    }, markdown: "## Revised content\nA corrected payroll guide.")
    allow(BlogPost).to receive(:all).and_return([ edited ])

    get edited.path
    expect(response.body).to include("A corrected payroll guide.")
  end

  it "renders flash messages for the current request on a cache hit" do
    get "/pricing"
    allow_any_instance_of(MarketingPagesController).to receive(:flash)
      .and_return({ "notice" => "Your personal message" })
    get "/pricing"
    expect(public_cache_hits).not_to be_empty
    expect(response.body).to include("Your personal message")

    allow_any_instance_of(MarketingPagesController).to receive(:flash).and_return({})
    get "/pricing"
    expect(response.body).not_to include("Your personal message")
  end

  it "keeps CSRF tokens unique to each session while reusing the public content" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    tokens = 2.times.map do
      browser = ActionDispatch::Integration::Session.new(Rails.application)
      browser.host! "lvh.me"
      browser.get "/pricing"
      expect(browser.response).to have_http_status(:ok)
      Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]
    end
    expect(tokens).to all(be_present)
    expect(tokens.uniq.length).to eq(2)
    expect(public_cache_hits).not_to be_empty
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  it "keeps signup and contact forms outside the shared content cache" do
    %w[/signup /contact].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css("form")).not_to be_empty
    end
    expect(cache_reads.select { |event| event[:key].to_s.include?("public-pages") }).to be_empty
  end
end
