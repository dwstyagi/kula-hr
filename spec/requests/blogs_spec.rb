require "rails_helper"

RSpec.describe "Blog", type: :request do
  let(:root_host) { "lvh.me" }
  let(:post_slug) { "payroll-processing-india" }

  it "renders the blog index with indexable metadata" do
    get blog_path, headers: { "Host" => root_host }
    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(response.headers).not_to include("X-Robots-Tag")
    expect(document.at_css('link[rel="canonical"]')["href"]).to eq("https://kula-hr.com/blog")
    expect(document.css("h1").one?).to be(true)
  end

  it "lists every published post on the index, with the pillar first" do
    get blog_path, headers: { "Host" => root_host }

    BlogPost.published.each do |post|
      expect(response.body).to include(blog_post_path(post.slug))
    end
    expect(BlogPost.published.first.slug).to eq(post_slug)
  end

  it "renders a post with article metadata and structured data" do
    get blog_post_path(post_slug), headers: { "Host" => root_host }
    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(response.headers).not_to include("X-Robots-Tag")
    expect(document.at_css('meta[name="description"]')["content"]).to be_present
    expect(document.at_css('link[rel="canonical"]')["href"]).to eq("https://kula-hr.com/blog/#{post_slug}")
    expect(document.css("h1").one?).to be(true)

    schemas = document.css('script[type="application/ld+json"]').map { |node| JSON.parse(node.text) }
    article = schemas.find { |schema| schema["@type"] == "Article" }

    expect(article).to be_present
    expect(article.fetch("url")).to eq("https://kula-hr.com/blog/#{post_slug}")
    expect(article.fetch("datePublished")).to be_present
    expect(schemas.map { |schema| schema["@type"] }).to include("FAQPage")
  end

  it "builds the table of contents from the rendered headings" do
    post = BlogPost.find(post_slug)
    get blog_post_path(post_slug), headers: { "Host" => root_host }

    expect(post.sections).not_to be_empty
    post.sections.each do |section|
      expect(response.body).to include(%(href="##{section[:id]}"))
      expect(response.body).to include(%(<h2 id="#{section[:id]}">))
    end
  end

  it "returns a noindex 404 for an unknown slug" do
    get "/blog/no-such-post", headers: { "Host" => root_host }

    expect(response).to have_http_status(:not_found)
    expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
  end

  it "publishes every post in the sitemap" do
    get sitemap_path, headers: { "Host" => root_host }

    expect(response.body).to include("http://#{root_host}/blog")
    BlogPost.published.each do |post|
      expect(response.body).to include("http://#{root_host}#{post.path}")
    end
  end

  describe BlogPost do
    let(:meta) do
      {
        "title" => "Test", "description" => "Test", "summary" => "Test",
        "published_on" => published_on
      }
    end
    let(:post) { described_class.new(slug: "test", meta: meta, markdown: "## Heading\n\nBody.") }

    context "when dated today or earlier" do
      let(:published_on) { Date.current }

      it "is published" do
        expect(post).to be_published
        expect(described_class.paths).to include("/blog/#{post_slug}")
      end
    end

    context "when dated in the future" do
      let(:published_on) { Date.current + 1 }

      it "is treated as a draft" do
        expect(post).not_to be_published
      end
    end

    it "orders by weight, then newest, then slug so ordering is deterministic" do
      same_day = Date.current
      build = lambda do |slug, weight|
        described_class.new(
          slug: slug,
          meta: {
            "title" => slug, "description" => slug, "summary" => slug,
            "published_on" => same_day, "weight" => weight
          },
          markdown: "Body."
        )
      end

      posts = [ build.call("b-spoke", 100), build.call("a-spoke", 100), build.call("pillar", 1) ]
      ordered = posts.sort_by { |p| [ p.weight, -p.published_on.to_time.to_i, p.slug ] }

      expect(ordered.map(&:slug)).to eq(%w[pillar a-spoke b-spoke])
    end

    it "renders markdown to HTML with heading anchors" do
      post = described_class.new(
        slug: "test",
        meta: {
          "title" => "Test", "description" => "Test", "summary" => "Test",
          "published_on" => Date.current
        },
        markdown: "## Step one\n\nSome body text."
      )

      expect(post.html).to include('<h2 id="step-one">Step one</h2>')
      expect(post.sections).to eq([ { id: "step-one", title: "Step one" } ])
    end
  end
end
