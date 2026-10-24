# frozen_string_literal: true

require "jekyll-cache-bust"
require "al_folio_core"

# al-folio's cache-bust filter fingerprints the theme Sass directory. LIMO's
# site-owned Sass lives in this repository, so include it in the same digest to
# prevent browsers from retaining stale CSS after a local design change.
module LimoCssCacheBust
  SITE_ROOT = File.expand_path("..", __dir__)

  private

  def directory_files_content
    upstream_content = super
    return upstream_content unless directory == "assets/_sass"

    local_files = Dir[File.join(SITE_ROOT, "_sass", "**", "*")].select { |path| File.file?(path) }
    local_files << File.join(SITE_ROOT, "assets", "css", "main.scss")

    local_content = local_files.select { |path| File.file?(path) }.uniq.sort.map { |path| File.read(path, encoding: "UTF-8") }.join
    upstream_content + local_content
  end
end

cache_digester = Jekyll::CacheBust::CacheDigester
cache_digester.prepend(LimoCssCacheBust) unless cache_digester.ancestors.include?(LimoCssCacheBust)
