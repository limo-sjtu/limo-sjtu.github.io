#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "set"
require "uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
PEOPLE_CATEGORIES = ["Faculty", "Post-doc", "PhD student", "Master student", "Undergraduate", "Alumni"].freeze
PEOPLE_STATUSES = %w[current alumni].freeze
ALUMNI_DEGREES = %w[phd masters].freeze
CV_SECTION_TYPES = %w[list list_groups map nested_list publications time_table].freeze
NEWS_KINDS = %w[award event general grant member preprint publication recruiting].freeze
BIB_ABBREVIATIONS = %w[Conference Journal Preprint Thesis].freeze
PLACEHOLDER_PATTERN = /\bxxxx(?:\.xx)?\b|Hobby\s+\d|link to the paper|title of position|name of school|Author\s+\d|Description\s+\d|Master in Subject|Bachelor in Subject/i
PEOPLE_PLACEHOLDER_PATTERN = /Welcome to my (?:webpage|homepage)/i
IDENTIFIER_PATTERN = /\A[a-z0-9]+(?:[_-][a-z0-9]+)*\z/
MEMBER_ID_PATTERN = /\A[a-z0-9]+(?:_[a-z0-9]+)*\z/
CV_YEAR_PATTERN = /\A(?:completed|\d{4}(?:\.\d{1,2})?(?:\s*-\s*(?:\d{4}(?:\.\d{1,2})?|now|present))?)\z/i
EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

errors = []
warnings = []

def relative(path)
  path.delete_prefix("#{ROOT}/")
end

def present?(value)
  !value.nil? && (!value.respond_to?(:empty?) || !value.empty?)
end

def nonempty_string?(value)
  value.is_a?(String) && !value.strip.empty?
end

def load_yaml(path, errors)
  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: true)
rescue Psych::Exception => e
  errors << "#{relative(path)}: invalid YAML (#{e.message.lines.first.strip})"
  nil
end

def load_front_matter(path, errors)
  source = File.read(path)
  match = source.match(/\A---\s*\n(.*?)\n---\s*(?:\n|\z)/m)
  unless match
    errors << "#{relative(path)}: missing YAML front matter"
    return nil
  end

  YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) || {}
rescue Psych::Exception => e
  errors << "#{relative(path)}: invalid front matter (#{e.message.lines.first.strip})"
  nil
end

def valid_http_url?(value)
  uri = URI.parse(value.to_s)
  uri.is_a?(URI::HTTP) && present?(uri.host)
rescue URI::InvalidURIError
  false
end

def blank_or_placeholder?(value)
  !present?(value) || value.to_s.strip.match?(/\A(?:none|n\/a)\z/i)
end

def scalar?(value)
  value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(Date) || value.is_a?(Time)
end

def parse_iso_date(value)
  return value if value.is_a?(Date)
  Date.iso8601(value.to_s)
rescue Date::Error
  nil
end

def each_scalar(value, path = [], &block)
  case value
  when Hash
    value.each { |key, child| each_scalar(child, path + [key], &block) }
  when Array
    value.each_with_index { |child, index| each_scalar(child, path + [index], &block) }
  else
    yield value, path
  end
end

def unwrap_bib_value(value)
  stripped = value.to_s.strip
  if (stripped.start_with?("{") && stripped.end_with?("}")) ||
     (stripped.start_with?("\"") && stripped.end_with?("\""))
    stripped[1...-1].strip
  else
    stripped
  end
end

def split_bib_fields(body)
  fields = []
  token = +""
  depth = 0
  quoted = false
  escaped = false

  body.each_char do |char|
    if escaped
      token << char
      escaped = false
      next
    end

    if char == "\\"
      token << char
      escaped = true
    elsif char == '"' && depth.zero?
      quoted = !quoted
      token << char
    elsif !quoted && char == "{"
      depth += 1
      token << char
    elsif !quoted && char == "}"
      depth -= 1
      token << char
    elsif !quoted && depth.zero? && char == ","
      fields << token
      token = +""
    else
      token << char
    end
  end
  fields << token unless token.strip.empty?
  fields
end

def parse_bibliography(path, errors)
  source = File.read(path)
  entries = []
  cursor = 0

  while (match = source.match(/@([A-Za-z]+)\s*\{\s*([^,\s]+)\s*,/, cursor))
    type = match[1].downcase
    key = match[2]
    opening = source.index("{", match.begin(0))
    depth = 1
    index = opening + 1
    quoted = false
    escaped = false

    while index < source.length && depth.positive?
      char = source[index]
      if escaped
        escaped = false
      elsif char == "\\"
        escaped = true
      elsif char == '"'
        quoted = !quoted
      elsif !quoted && char == "{"
        depth += 1
      elsif !quoted && char == "}"
        depth -= 1
      end
      index += 1
    end

    if depth.positive?
      errors << "#{relative(path)}: unclosed BibTeX entry #{key.inspect}"
      break
    end

    body = source[match.end(0)...(index - 1)]
    body = body.lines.reject { |line| line.lstrip.start_with?("%") }.join
    fields = Hash.new { |hash, field| hash[field] = [] }
    split_bib_fields(body).each do |part|
      field_match = part.match(/\A\s*([A-Za-z][A-Za-z0-9_-]*)\s*=\s*(.*?)\s*\z/m)
      next unless field_match

      fields[field_match[1].downcase] << field_match[2]
    end

    entries << {
      type: type,
      key: key,
      line: source[0...match.begin(0)].count("\n") + 1,
      fields: fields
    }
    cursor = index
  end
  entries
end

# Research and publication taxonomies ----------------------------------------

publication_topics_path = File.join(ROOT, "_data", "publication_topics.yml")
publication_topics = load_yaml(publication_topics_path, errors)
publication_topic_ids = []
if publication_topics.is_a?(Array)
  publication_topics.each_with_index do |topic, index|
    label = "_data/publication_topics.yml: item #{index + 1}"
    unless topic.is_a?(Hash)
      errors << "#{label} must be a mapping"
      next
    end

    %w[id label publication_label].each do |field|
      errors << "#{label}: missing #{field.inspect}" unless present?(topic[field])
    end
    id = topic["id"].to_s
    errors << "#{label}: id must use lowercase letters, digits, and hyphens" unless id.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    publication_topic_ids << id unless id.empty?
  end
  publication_topic_ids.group_by { |id| id }.each do |id, matches|
    errors << "_data/publication_topics.yml: duplicate id #{id.inspect}" if matches.length > 1
  end
else
  errors << "_data/publication_topics.yml: top-level value must be a list"
  publication_topics = []
end

research_areas_path = File.join(ROOT, "_data", "research_areas.yml")
research_areas = load_yaml(research_areas_path, errors)
if research_areas.is_a?(Array)
  ids = []
  research_areas.each_with_index do |area, index|
    label = "_data/research_areas.yml: item #{index + 1}"
    unless area.is_a?(Hash)
      errors << "#{label} must be a mapping"
      next
    end

    %w[id title summary description methods applications publication_topics].each do |field|
      errors << "#{label}: missing #{field.inspect}" unless present?(area[field])
    end

    id = area["id"].to_s
    errors << "#{label}: id must use lowercase letters, digits, and hyphens" unless id.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    ids << id unless id.empty?

    %w[methods applications].each do |field|
      errors << "#{label}: #{field} must be a list" unless area[field].is_a?(Array)
    end

    topics = area["publication_topics"]
    next unless topics.is_a?(Array)

    topics.each do |topic_id|
      unless topic_id.is_a?(String)
        errors << "#{label}: publication_topics entries must be topic id strings"
        next
      end
      errors << "#{label}: unknown publication topic #{topic_id.inspect}" unless publication_topic_ids.include?(topic_id)
    end
  end

  ids.group_by { |id| id }.each do |id, matches|
    errors << "_data/research_areas.yml: duplicate id #{id.inspect}" if matches.length > 1
  end
else
  errors << "_data/research_areas.yml: top-level value must be a list"
  research_areas = []
end

# People and CV data ----------------------------------------------------------

referenced_cvs = Set.new
people_by_cv = {}
people_member_ids = []
people_files = Dir[File.join(ROOT, "_people", "*.md")].sort

people_files.each do |path|
  data = load_front_matter(path, errors)
  next unless data.is_a?(Hash)

  label = relative(path)
  filename_id = File.basename(path, ".md")
  if data["layout"] == "limo-member" && !filename_id.match?(IDENTIFIER_PATTERN)
    warnings << "#{label}: member identifiers must be lowercase; preserve the former URL with a redirect page during migration"
  end
  %w[layout title member_id description img importance category status position webpage].each do |field|
    errors << "#{label}: missing #{field.inspect}" unless present?(data[field]) || data[field] == false
  end

  member_id = data["member_id"].to_s
  unless member_id.empty?
    errors << "#{label}: member_id must use lowercase letters, digits, and underscores" unless member_id.match?(MEMBER_ID_PATTERN)
    errors << "#{label}: member_id must match the page filename (expected #{filename_id.inspect})" unless member_id == filename_id
    people_member_ids << member_id
  end

  unless PEOPLE_CATEGORIES.include?(data["category"])
    errors << "#{label}: category must be one of #{PEOPLE_CATEGORIES.join(', ')}"
  end
  errors << "#{label}: status must be current or alumni" unless PEOPLE_STATUSES.include?(data["status"])
  if data["category"] == "Alumni" && data["status"] != "alumni"
    errors << "#{label}: Alumni category requires status alumni"
  elsif data["category"] != "Alumni" && data["status"] != "current"
    errors << "#{label}: current membership categories require status current"
  end
  errors << "#{label}: importance must be an integer" unless data["importance"].is_a?(Integer)
  if ["PhD student", "Master student", "Alumni"].include?(data["category"]) && !present?(data["sort_name"])
    errors << "#{label}: students and alumni require sort_name in 'Family-name Given-name' order"
  end
  if data["category"] == "Alumni"
    unless ALUMNI_DEGREES.include?(data["alumni_degree"])
      errors << "#{label}: Alumni require alumni_degree to be phd or masters"
    end
  elsif data.key?("alumni_degree")
    errors << "#{label}: alumni_degree is only allowed for Alumni"
  end
  errors << "#{label}: webpage must be true or false" unless [true, false].include?(data["webpage"])
  errors << "#{label}: legacy yaml field is not allowed; use cv" if data.key?("yaml")

  image = File.join(ROOT, "assets", "img", "people", data["img"].to_s)
  errors << "#{label}: referenced image does not exist: #{relative(image)}" unless File.file?(image)

  %w[scholar github].each do |field|
    next unless present?(data[field])
    errors << "#{label}: #{field} must be a full http(s) URL" unless valid_http_url?(data[field])
  end

  if present?(data["redirect"]) && !valid_http_url?(data["redirect"]) && !data["redirect"].to_s.match?(%r{\A/[^\s]*\z})
    errors << "#{label}: redirect must be a full http(s) URL or a root-relative path"
  end

  if present?(data["local_profile"]) && !data["local_profile"].to_s.match?(%r{\A/[^\s]*\z})
    errors << "#{label}: local_profile must be a root-relative path"
  end

  if data.key?("research_areas")
    unless data["research_areas"].is_a?(Array)
      errors << "#{label}: research_areas must be a list"
    else
      invalid_areas = data["research_areas"] - publication_topic_ids
      errors << "#{label}: unsupported research areas: #{invalid_areas.join(', ')}" if invalid_areas.any?
    end
  end

  case data["layout"]
  when "limo-member"
    cv = data["cv"].to_s
    errors << "#{label}: limo-member requires a cv identifier" if cv.empty?
    errors << "#{label}: cv identifier must match the page filename (expected #{filename_id.inspect})" unless cv == filename_id
    referenced_cvs << cv unless cv.empty?
    people_by_cv[cv] = data unless cv.empty?
  when "page"
    errors << "#{label}: redirect-only page requires redirect" unless present?(data["redirect"])
    errors << "#{label}: redirect-only page must not define cv" if present?(data["cv"])
    errors << "#{label}: redirect-only page must set sitemap to false" unless data["sitemap"] == false
  else
    errors << "#{label}: layout must be limo-member or page"
  end

  source = File.read(path)
  body = source.sub(/\A---\s*\n.*?\n---\s*/m, "")
  errors << "#{label}: placeholder profile introduction is not allowed" if body.match?(PEOPLE_PLACEHOLDER_PATTERN)
end

people_member_ids.group_by { |member_id| member_id }.each do |member_id, matches|
  errors << "_people: duplicate member_id #{member_id.inspect}" if matches.length > 1
end
people_member_id_set = people_member_ids.to_set

cv_files = Dir[File.join(ROOT, "_data", "cv", "*.yml")].sort
available_cvs = cv_files.map { |path| File.basename(path, ".yml") }.to_set

(referenced_cvs - available_cvs).sort.each do |cv|
  errors << "_people/#{cv}.md: missing _data/cv/#{cv}.yml"
end
(available_cvs - referenced_cvs).sort.each do |cv|
  errors << "_data/cv/#{cv}.yml: orphaned CV data is not referenced by a member page"
end

cv_files.each do |path|
  data = load_yaml(path, errors)
  next unless data

  label = relative(path)
  cv_id = File.basename(path, ".yml")
  warnings << "#{label}: legacy mixed-case identifier; migrate together with its profile URL when safe" unless cv_id.match?(IDENTIFIER_PATTERN)
  unless data.is_a?(Array)
    errors << "#{label}: top-level value must be a list of sections"
    next
  end

  data.each_with_index do |section, index|
    unless section.is_a?(Hash)
      errors << "#{label}: section #{index + 1} must be a mapping"
      next
    end

    title = section["title"]
    type = section["type"]
    contents = section["contents"]
    errors << "#{label}: section #{index + 1} is missing title" unless present?(title)
    errors << "#{label}: section #{title || index + 1} has unsupported type #{type.inspect}" unless CV_SECTION_TYPES.include?(type)
    errors << "#{label}: section #{title || index + 1} contents must be a list" unless contents.is_a?(Array)
    next unless contents.is_a?(Array) && CV_SECTION_TYPES.include?(type)

    contents.each_with_index do |item, item_index|
      item_label = "#{label}: section #{title || index + 1}, item #{item_index + 1}"
      case type
      when "map"
        unless item.is_a?(Hash)
          errors << "#{item_label} must be a mapping"
          next
        end
        errors << "#{item_label}: missing name" unless present?(item["name"])
        has_value = item.key?("value") && !blank_or_placeholder?(item["value"])
        has_links = item["links"].is_a?(Array) && item["links"].any?
        errors << "#{item_label}: requires a value or a non-empty links list" unless has_value || has_links
        if item.key?("value") && blank_or_placeholder?(item["value"])
          warnings << "#{item_label}: replace #{item['value'].inspect} with a real value or remove this row"
        end
        if item.key?("links")
          unless item["links"].is_a?(Array) && item["links"].any?
            errors << "#{item_label}: links must be a non-empty list"
            next
          end
          item["links"].each_with_index do |link, link_index|
            link_label = "#{item_label}, link #{link_index + 1}"
            unless link.is_a?(Hash)
              errors << "#{link_label} must be a mapping"
              next
            end
            errors << "#{link_label}: missing name" unless present?(link["name"])
            errors << "#{link_label}: link must be a full http(s) URL" unless valid_http_url?(link["link"])
          end
        end
      when "time_table"
        unless item.is_a?(Hash)
          errors << "#{item_label} must be a mapping"
          next
        end
        unless present?(item["title"]) || item["items"].is_a?(Array)
          errors << "#{item_label}: requires title or an items list"
        end
      when "publications"
        unless item.is_a?(Hash)
          errors << "#{item_label} must be a mapping"
          next
        end
        %w[name publisher authors].each do |field|
          errors << "#{item_label}: missing #{field}" unless present?(item[field])
        end
        warnings << "#{item_label}: publication year is missing" unless present?(item["year"])
      when "list"
        errors << "#{item_label} must be text or a mapping" unless item.is_a?(String) || item.is_a?(Hash)
      when "nested_list", "list_groups"
        errors << "#{item_label} must be a mapping" unless item.is_a?(Hash)
      end

      next unless item.is_a?(Hash)

      if item.key?("year")
        if !scalar?(item["year"])
          errors << "#{item_label}: year must be text or a number"
        elsif !item["year"].to_s.strip.match?(CV_YEAR_PATTERN)
          warnings << "#{item_label}: non-standard year/date #{item['year'].inspect}; prefer YYYY.MM - YYYY.MM/Present"
        end
      end
      if present?(item["url"]) && !valid_http_url?(item["url"])
        errors << "#{item_label}: url must be a full http(s) URL"
      end
    end
  end

  each_scalar(data) do |value, value_path|
    next unless value.is_a?(String) && value.match?(PLACEHOLDER_PATTERN)
    errors << "#{label}: placeholder content at #{value_path.join('.')} (#{value.inspect})"
  end

  each_scalar(data) do |value, value_path|
    next unless value.is_a?(String) && value.match?(EMAIL_PATTERN)
    warnings << "#{label}: public email address at #{value_path.join('.')} should use the anti-spam 'name at domain dot com' form"
  end

  member = people_by_cv[cv_id]
  next unless member

  education = data.find { |section| section.is_a?(Hash) && section["title"].to_s.match?(/education/i) }
  education_items = education.is_a?(Hash) && education["contents"].is_a?(Array) ? education["contents"] : []
  if member["status"] == "alumni"
    education_items.each_with_index do |item, index|
      next unless item.is_a?(Hash) && item["year"].to_s.match?(/\b(?:now|present)\b/i)
      warnings << "#{label}: alumni education item #{index + 1} still ends in Now/Present"
    end

    expected_degree = member["alumni_degree"] == "phd" ? /\b(?:ph\.?d|doctor)/i : /\bmaster/i
    unless education_items.any? { |item| item.is_a?(Hash) && item["title"].to_s.match?(expected_degree) }
      warnings << "#{label}: alumni degree #{member['alumni_degree'].inspect} is not represented in the Education section"
    end
  end

  interests_section = data.find { |section| section.is_a?(Hash) && section["type"] == "map" }
  interests_item = interests_section&.fetch("contents", [])&.find do |item|
    item.is_a?(Hash) && item["name"].to_s.match?(/research interests?/i)
  end
  interests = interests_item.is_a?(Hash) ? interests_item["value"].to_s.downcase : ""
  interest_patterns = {
    "imaging" => /imag|inverse|\bct\b|\bmri\b|\bpet\b|\bspect\b/,
    "optimization" => /optimi/,
    "learning" => /learn|neural|generative|dictionary/
  }
  Array(member["research_areas"]).each do |area|
    pattern = interest_patterns[area]
    next unless pattern && present?(interests)
    next if interests.match?(pattern)
    warnings << "#{label}: profile declares research area #{area.inspect}, but the CV Research Interests text does not mention it"
  end
end

# News -----------------------------------------------------------------------

news_files = Dir[File.join(ROOT, "_news", "*.md")].sort
news_publication_references = []
news_files.each do |path|
  data = load_front_matter(path, errors)
  next unless data.is_a?(Hash)

  label = relative(path)
  filename = File.basename(path)
  filename_match = filename.match(/\A(\d{4}-\d{2}-\d{2})-[a-z0-9][a-z0-9-]*\.md\z/)
  errors << "#{label}: filename must use YYYY-MM-DD-short-slug.md" unless filename_match

  %w[layout title description date kind inline related_posts].each do |field|
    errors << "#{label}: missing #{field.inspect}" unless present?(data[field]) || data[field] == false
  end
  errors << "#{label}: layout must be post" unless data["layout"] == "post"
  errors << "#{label}: kind must be one of #{NEWS_KINDS.join(', ')}" unless NEWS_KINDS.include?(data["kind"])
  errors << "#{label}: inline must be true or false" unless [true, false].include?(data["inline"])
  errors << "#{label}: related_posts must be true or false" unless [true, false].include?(data["related_posts"])

  if %w[publication preprint].include?(data["kind"])
    if present?(data["publication_key"])
      news_publication_references << [label, data["publication_key"].to_s]
    else
      errors << "#{label}: #{data['kind']} news requires publication_key"
    end
  elsif data.key?("publication_key")
    warnings << "#{label}: publication_key is normally only used for publication or preprint news"
  end

  date = data["date"]
  date_text = date.respond_to?(:strftime) ? date.strftime("%Y-%m-%d") : date.to_s
  if filename_match && filename_match[1] != date_text
    errors << "#{label}: filename date #{filename_match[1]} does not match front matter date #{date_text}"
  end
end

# Bibliography ---------------------------------------------------------------

bib_files = Dir[File.join(ROOT, "_bibliography", "*.bib")].sort
expected_bib = File.join(ROOT, "_bibliography", "papers.bib")
unless bib_files == [expected_bib]
  errors << "_bibliography: papers.bib must be the only BibTeX source (found #{bib_files.map { |path| File.basename(path) }.join(', ')})"
end

bib_entries = File.file?(expected_bib) ? parse_bibliography(expected_bib, errors) : []
bib_keys = bib_entries.map { |entry| entry[:key] }.to_set
news_publication_references.each do |label, publication_key|
  errors << "#{label}: publication_key #{publication_key.inspect} does not exist in _bibliography/papers.bib" unless bib_keys.include?(publication_key)
end
duplicate_keys = bib_entries.group_by { |entry| entry[:key] }.select { |_key, group| group.length > 1 }
duplicate_keys.each do |key, group|
  errors << "_bibliography/papers.bib: duplicate citation key #{key.inspect} at lines #{group.map { |entry| entry[:line] }.join(', ')}"
end

missing_links = []
homepage_featured_entries = []
bib_entries.each do |entry|
  label = "_bibliography/papers.bib:#{entry[:line]} (#{entry[:key]})"
  fields = entry[:fields]

  fields.each do |field, values|
    errors << "#{label}: duplicate field #{field.inspect}" if values.length > 1
  end

  %w[title author year abbr bibtex_show cate_primary selected].each do |field|
    errors << "#{label}: missing #{field.inspect}" unless fields.key?(field) && present?(unwrap_bib_value(fields[field].last))
  end

  venue_fields = entry[:type] == "inproceedings" ? ["booktitle"] : entry[:type] == "phdthesis" ? ["school"] : ["journal"]
  venue_fields.each do |field|
    errors << "#{label}: #{entry[:type]} entry requires #{field.inspect}" unless fields.key?(field) && present?(unwrap_bib_value(fields[field].last))
  end

  key = entry[:key]
  errors << "#{label}: citation key must use lowercase letters, digits, underscores, or hyphens" unless key.match?(/\A[a-z][a-z0-9_-]*\z/)

  abbr = unwrap_bib_value(fields["abbr"]&.last)
  errors << "#{label}: abbr must be one of #{BIB_ABBREVIATIONS.join(', ')}" if present?(abbr) && !BIB_ABBREVIATIONS.include?(abbr)
  if abbr == "Conference" && entry[:type] != "inproceedings"
    errors << "#{label}: Conference entries must use @inproceedings"
  end

  %w[journal booktitle].each do |field|
    next unless fields.key?(field)
    errors << "#{label}: #{field} must not contain HTML" if unwrap_bib_value(fields[field].last).match?(%r{</?[A-Za-z][^>]*>})
  end

  primary = unwrap_bib_value(fields["cate_primary"]&.last)
  errors << "#{label}: cate_primary must be one of #{publication_topic_ids.join(', ')}" if present?(primary) && !publication_topic_ids.include?(primary)

  secondary = unwrap_bib_value(fields["cate_secondary"]&.last)
  allowed_secondary = publication_topic_ids + ["none"]
  errors << "#{label}: cate_secondary must be one of #{allowed_secondary.join(', ')}" if present?(secondary) && !allowed_secondary.include?(secondary)

  if fields.key?("limo_members")
    member_ids = unwrap_bib_value(fields["limo_members"].last).split(",").map(&:strip).reject(&:empty?)
    errors << "#{label}: limo_members must contain at least one member_id" if member_ids.empty?
    member_ids.group_by { |member_id| member_id }.each do |member_id, matches|
      errors << "#{label}: duplicate limo_members identifier #{member_id.inspect}" if matches.length > 1
    end
    member_ids.each do |member_id|
      errors << "#{label}: invalid limo_members identifier #{member_id.inspect}" unless member_id.match?(MEMBER_ID_PATTERN)
      errors << "#{label}: limo_members references unknown member_id #{member_id.inspect}" unless people_member_id_set.include?(member_id)
    end
  end

  %w[bibtex_show selected homepage_featured].each do |field|
    value = unwrap_bib_value(fields[field]&.last)
    errors << "#{label}: #{field} must be true or false" if present?(value) && !%w[true false].include?(value)
  end

  year_text = unwrap_bib_value(fields["year"]&.last)
  if present?(year_text)
    if year_text.match?(/\A\d{4}\z/) && year_text.to_i.between?(1900, Date.today.year + 1)
      # Valid year; rendered order is enforced through the Scholar config below.
    else
      errors << "#{label}: year must be a plausible four-digit year"
    end
  end

  if unwrap_bib_value(fields["homepage_featured"]&.last) == "true"
    homepage_featured_entries << entry
    errors << "#{label}: homepage_featured=true also requires selected=true" unless unwrap_bib_value(fields["selected"]&.last) == "true"
  end

  missing_links << entry[:key] unless fields.key?("html") || fields.key?("doi")
end

unless homepage_featured_entries.length == 3
  errors << "_bibliography/papers.bib: exactly 3 entries must set homepage_featured=true (found #{homepage_featured_entries.length})"
end

site_config = load_yaml(File.join(ROOT, "_config.yml"), errors)
if site_config.is_a?(Hash) && site_config["scholar"].is_a?(Hash)
  scholar = site_config["scholar"]
  errors << "_config.yml: scholar.sort_by must be 'year, month'" unless scholar["sort_by"].to_s == "year, month"
  errors << "_config.yml: scholar.order must be descending" unless scholar["order"].to_s == "descending"
else
  errors << "_config.yml: missing scholar configuration"
end

warnings << "#{missing_links.length} historical bibliography entries have no html or doi link" if missing_links.any?

# Activities -----------------------------------------------------------------

activity_counts = { events: 0, talks: 0, services: 0 }

events_path = File.join(ROOT, "_data", "activity", "events.yml")
events = load_yaml(events_path, errors)
if events.is_a?(Array)
  event_ids = []
  events.each_with_index do |event, index|
    label = "_data/activity/events.yml: item #{index + 1}"
    unless event.is_a?(Hash)
      errors << "#{label} must be a mapping"
      next
    end
    %w[id start_date end_date date_display session conference location organizers lang].each do |field|
      errors << "#{label}: missing #{field.inspect}" unless present?(event[field])
    end
    %w[id date_display session conference location lang].each do |field|
      errors << "#{label}: #{field} must be non-empty text" if present?(event[field]) && !nonempty_string?(event[field])
    end
    id = event["id"].to_s
    errors << "#{label}: id must use lowercase letters, digits, and hyphens" unless id.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    event_ids << id unless id.empty?
    start_date = parse_iso_date(event["start_date"])
    end_date = parse_iso_date(event["end_date"])
    errors << "#{label}: start_date must use YYYY-MM-DD" unless start_date
    errors << "#{label}: end_date must use YYYY-MM-DD" unless end_date
    errors << "#{label}: end_date must not precede start_date" if start_date && end_date && end_date < start_date
    errors << "#{label}: lang must be en or zh-CN" unless %w[en zh-CN].include?(event["lang"])
    if event["organizers"].is_a?(Array) && event["organizers"].any?
      event["organizers"].each_with_index do |organizer, organizer_index|
        organizer_label = "#{label}, organizer #{organizer_index + 1}"
        unless organizer.is_a?(Hash)
          errors << "#{organizer_label} must be a mapping"
          next
        end
        %w[name affiliation].each do |field|
          errors << "#{organizer_label}: #{field} must be non-empty text" unless nonempty_string?(organizer[field])
        end
      end
    else
      errors << "#{label}: organizers must be a non-empty list"
    end
    %w[session_url conf_url].each do |field|
      errors << "#{label}: #{field} must be a full http(s) URL" if present?(event[field]) && !valid_http_url?(event[field])
    end
    activity_counts[:events] += 1
  end
  event_ids.group_by { |id| id }.each do |id, matches|
    errors << "_data/activity/events.yml: duplicate id #{id.inspect}" if matches.length > 1
  end
else
  errors << "_data/activity/events.yml: top-level value must be a list"
end

talks_path = File.join(ROOT, "_data", "activity", "talks.yml")
talks = load_yaml(talks_path, errors)
if talks.is_a?(Array)
  talk_ids = []
  talks.each_with_index do |talk, index|
    label = "_data/activity/talks.yml: item #{index + 1}"
    unless talk.is_a?(Hash)
      errors << "#{label} must be a mapping"
      next
    end
    core_fields = %w[id start_date end_date date_display title conference location lang]
    if core_fields.none? { |field| present?(talk[field]) }
      warnings << "#{label}: empty placeholder row should be removed"
      next
    end
    core_fields.each { |field| errors << "#{label}: missing #{field.inspect}" unless present?(talk[field]) }
    %w[id date_display title conference location lang].each do |field|
      errors << "#{label}: #{field} must be non-empty text" if present?(talk[field]) && !nonempty_string?(talk[field])
    end
    id = talk["id"].to_s
    errors << "#{label}: id must use lowercase letters, digits, and hyphens" unless id.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    talk_ids << id unless id.empty?
    start_date = parse_iso_date(talk["start_date"])
    end_date = parse_iso_date(talk["end_date"])
    errors << "#{label}: start_date must use YYYY-MM-DD" unless start_date
    errors << "#{label}: end_date must use YYYY-MM-DD" unless end_date
    errors << "#{label}: end_date must not precede start_date" if start_date && end_date && end_date < start_date
    errors << "#{label}: lang must be en or zh-CN" unless %w[en zh-CN].include?(talk["lang"])
    %w[session_url conf_url].each do |field|
      errors << "#{label}: #{field} must be a full http(s) URL" if present?(talk[field]) && !valid_http_url?(talk[field])
    end
    if present?(talk["slides"])
      errors << "#{label}: slides must be text" unless talk["slides"].is_a?(String)
      slides = talk["slides"].to_s
      unless slides.start_with?("/") || valid_http_url?(slides)
        errors << "#{label}: slides must be a root-relative path or full http(s) URL"
      end
      if slides.start_with?("/")
        slides_path = File.join(ROOT, slides.delete_prefix("/"))
        errors << "#{label}: slides file does not exist: #{relative(slides_path)}" unless File.file?(slides_path)
      end
      warnings << "#{label}: example_pdf.pdf is demonstration content and should be replaced or removed" if File.basename(slides) == "example_pdf.pdf"
    end
    activity_counts[:talks] += 1
  end
  talk_ids.group_by { |id| id }.each do |id, matches|
    errors << "_data/activity/talks.yml: duplicate id #{id.inspect}" if matches.length > 1
  end
else
  errors << "_data/activity/talks.yml: top-level value must be a list"
end

services_path = File.join(ROOT, "_data", "activity", "services.yml")
services = load_yaml(services_path, errors)
review_venues = Hash.new { |hash, venue| hash[venue] = [] }
if services.is_a?(Array)
  services.each_with_index do |section, section_index|
    label = "_data/activity/services.yml: section #{section_index + 1}"
    unless section.is_a?(Hash)
      errors << "#{label} must be a mapping"
      next
    end
    errors << "#{label}: missing title" unless present?(section["title"])
    errors << "#{label}: type must be service or review" unless %w[service review].include?(section["type"])
    unless section["contents"].is_a?(Array)
      errors << "#{label}: contents must be a list"
      next
    end
    section["contents"].each_with_index do |item, item_index|
      item_label = "#{label}, item #{item_index + 1}"
      unless item.is_a?(Hash)
        errors << "#{item_label} must be a mapping"
        next
      end
      if section["type"] == "service"
        %w[year role venue].each { |field| errors << "#{item_label}: missing #{field.inspect}" unless present?(item[field]) }
        errors << "#{item_label}: year must be text or a number" if item.key?("year") && !scalar?(item["year"])
        errors << "#{item_label}: venue_url must be a full http(s) URL" if present?(item["venue_url"]) && !valid_http_url?(item["venue_url"])
      elsif section["type"] == "review"
        errors << "#{item_label}: missing title" unless present?(item["title"])
        unless item["description"].is_a?(Array)
          errors << "#{item_label}: description must be a list"
          next
        end
        item["description"].each_with_index do |venue, venue_index|
          unless nonempty_string?(venue)
            errors << "#{item_label}: description item #{venue_index + 1} must be non-empty text"
            next
          end
          review_venues[venue.strip] << item_label
        end
      end
      activity_counts[:services] += 1
    end
  end
else
  errors << "_data/activity/services.yml: top-level value must be a list"
end
review_venues.each do |venue, locations|
  warnings << "_data/activity/services.yml: duplicate review venue #{venue.inspect} in #{locations.join(' and ')}" if locations.length > 1
end

if warnings.any?
  puts "Warnings:"
  warnings.each { |warning| puts "  - #{warning}" }
end

if errors.any?
  warn "Content validation failed with #{errors.length} error#{errors.length == 1 ? '' : 's'}:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

featured_keys = homepage_featured_entries.map { |entry| entry[:key] }.join(", ")
puts "Content validation passed: #{publication_topics.length} publication topics, #{research_areas.length} research areas, #{people_files.length} people, #{cv_files.length} CV files, #{news_files.length} news items, #{bib_entries.length} publications, #{activity_counts[:events]} events, #{activity_counts[:talks]} talks, and #{activity_counts[:services]} service/review groups."
puts "Homepage featured publication keys: #{featured_keys}" unless featured_keys.empty?
