module PublicPagesHelper
  # Rails adds a digest of the template and its partials. Include data defined
  # outside templates too, plus locale and mount path to keep links correct.
  def public_page_cache_key(*content)
    [ "public-pages", request.path, request.script_name, I18n.locale,
      Digest::SHA256.hexdigest(content.to_json) ]
  end
end
