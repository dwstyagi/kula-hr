# Blog posts are Markdown files on disk, not database rows. Each file in
# app/content/blog/ is one post; the filename is the URL slug. Routes, the
# sitemap and the public indexing allowlist all derive from this collection, so
# publishing a post is a single file addition with no companion edits to forget.
class BlogPost
  CONTENT_DIR = Rails.root.join("app/content/blog")
  FRONTMATTER = /\A---\s*\n(?<yaml>.*?)\n---\s*\n(?<body>.*)\z/m
  WORDS_PER_MINUTE = 220

  class NotFound < StandardError; end

  # Posts sort by weight first, then newest date. Pillar posts set a low weight
  # in frontmatter to pin them above the spokes that link to them.
  DEFAULT_WEIGHT = 100

  attr_reader :slug, :title, :description, :summary, :category, :weight,
              :published_on, :updated_on, :takeaways, :faqs, :hero_image, :markdown

  def self.all
    return load_all unless cache?

    @all ||= load_all
  end

  # Drafts are posts dated in the future: they stay out of the index, the
  # sitemap and the indexing allowlist until their date arrives.
  def self.published
    all.select(&:published?)
  end

  def self.find(slug)
    published.find { |post| post.slug == slug } || raise(NotFound, "No published post: #{slug}")
  end

  def self.paths
    published.map(&:path)
  end

  # Slug is the final tie-break so ordering stays identical across processes:
  # sort_by is not stable, and posts published on the same day are common.
  def self.load_all
    Dir.glob(CONTENT_DIR.join("*.md")).sort.map { |file| from_file(file) }
       .sort_by { |post| [ post.weight, -post.published_on.to_time.to_i, post.slug ] }
  end
  private_class_method :load_all

  def self.from_file(file)
    match = File.read(file).match(FRONTMATTER)
    raise "Missing YAML frontmatter in #{file}" if match.nil?

    new(
      slug: File.basename(file, ".md"),
      meta: YAML.safe_load(match[:yaml], permitted_classes: [ Date ]),
      markdown: match[:body]
    )
  end
  private_class_method :from_file

  def self.cache?
    Rails.env.production?
  end
  private_class_method :cache?

  def initialize(slug:, meta:, markdown:)
    @slug         = slug
    @markdown     = markdown
    @title        = meta.fetch("title")
    @description  = meta.fetch("description")
    @summary      = meta.fetch("summary")
    @published_on = meta.fetch("published_on")
    @updated_on   = meta["updated_on"] || @published_on
    @category     = meta["category"] || "Payroll"
    @weight       = meta["weight"] || DEFAULT_WEIGHT
    @hero_image   = meta["hero_image"]
    @takeaways    = Array(meta["takeaways"])
    @faqs         = Array(meta["faqs"])
  end

  def published?
    published_on <= Date.current
  end

  def path
    "/blog/#{slug}"
  end

  def url
    "https://kula-hr.com#{path}"
  end

  def html
    @html ||= Kramdown::Document.new(markdown, auto_ids: true, input: "kramdown").to_html.html_safe
  end

  # Table-of-contents entries, read back out of the rendered HTML so the anchor
  # IDs always match the ones kramdown generated for the headings.
  def sections
    @sections ||= html.to_str.scan(%r{<h2 id="([^"]+)">(.*?)</h2>}m).map do |id, heading|
      { id: id, title: heading.gsub(/<[^>]+>/, "").strip }
    end
  end

  def reading_minutes
    @reading_minutes ||= [ (markdown.split.size / WORDS_PER_MINUTE.to_f).ceil, 1 ].max
  end
end
