#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "set"
require "uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
PEOPLE_CATEGORIES = ["Faculty", "Post-doc", "PhD student", "Master student", "Undergraduate", "Alumni"].freeze
CV_SECTION_TYPES = %w[list list_groups map nested_list publications time_table].freeze
NEWS_KINDS = %w[award event general member publication].freeze
BIB_ABBREVIATIONS = %w[Conference Journal Preprint Thesis].freeze
BIB_CATEGORIES = %w[imaging learning optimization].freeze

errors = []
warnings = []

def relative(path)
  path.delete_prefix("#{ROOT}/")
end

def present?(value)
  !value.nil? && (!value.respond_to?(:empty?) || !value.empty?)
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

# People and CV data ----------------------------------------------------------

referenced_cvs = Set.new
people_files = Dir[File.join(ROOT, "_people", "*.md")].sort

people_files.each do |path|
  data = load_front_matter(path, errors)
  next unless data.is_a?(Hash)

  label = relative(path)
  %w[layout title img importance category webpage].each do |field|
    errors << "#{label}: missing #{field.inspect}" unless present?(data[field]) || data[field] == false
  end

  unless PEOPLE_CATEGORIES.include?(data["category"])
    errors << "#{label}: category must be one of #{PEOPLE_CATEGORIES.join(', ')}"
  end
  errors << "#{label}: importance must be an integer" unless data["importance"].is_a?(Integer)
  errors << "#{label}: webpage must be true or false" unless [true, false].include?(data["webpage"])
  errors << "#{label}: legacy yaml field is not allowed; use cv" if data.key?("yaml")

  image = File.join(ROOT, "assets", "img", "people", data["img"].to_s)
  errors << "#{label}: referenced image does not exist: #{relative(image)}" unless File.file?(image)

  %w[redirect scholar github].each do |field|
    next unless present?(data[field])
    errors << "#{label}: #{field} must be a full http(s) URL" unless valid_http_url?(data[field])
  end

  case data["layout"]
  when "cvpage"
    cv = data["cv"].to_s
    errors << "#{label}: cvpage requires a cv identifier" if cv.empty?
    expected = File.basename(path, ".md")
    errors << "#{label}: cv identifier must match the page filename (expected #{expected.inspect})" unless cv == expected
    referenced_cvs << cv unless cv.empty?
  when "page"
    errors << "#{label}: redirect-only page requires redirect" unless present?(data["redirect"])
    errors << "#{label}: redirect-only page must not define cv" if present?(data["cv"])
  else
    errors << "#{label}: layout must be cvpage or page"
  end
end

cv_files = Dir[File.join(ROOT, "_data", "cv", "*.yml")].sort
available_cvs = cv_files.map { |path| File.basename(path, ".yml") }.to_set

(referenced_cvs - available_cvs).sort.each do |cv|
  errors << "_people/#{cv}.md: missing _data/cv/#{cv}.yml"
end
(available_cvs - referenced_cvs).sort.each do |cv|
  errors << "_data/cv/#{cv}.yml: orphaned CV data is not referenced by a member page"
end

placeholder_pattern = /\bxxxx(?:\.xx)?\b|Hobby\s+\d|link to the paper|title of position|name of school|Author\s+\d|Description\s+\d|Master in Subject|Bachelor in Subject/i

cv_files.each do |path|
  data = load_yaml(path, errors)
  next unless data

  label = relative(path)
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
  end

  each_scalar(data) do |value, value_path|
    next unless value.is_a?(String) && value.match?(placeholder_pattern)
    errors << "#{label}: placeholder content at #{value_path.join('.')} (#{value.inspect})"
  end
end

# News -----------------------------------------------------------------------

news_files = Dir[File.join(ROOT, "_news", "*.md")].sort
news_files.each do |path|
  data = load_front_matter(path, errors)
  next unless data.is_a?(Hash)

  label = relative(path)
  filename = File.basename(path)
  filename_match = filename.match(/\A(\d{4}-\d{2}-\d{2})-[a-z0-9][a-z0-9-]*\.md\z/)
  errors << "#{label}: filename must use YYYY-MM-DD-short-slug.md" unless filename_match

  %w[layout title date kind inline related_posts].each do |field|
    errors << "#{label}: missing #{field.inspect}" unless present?(data[field]) || data[field] == false
  end
  errors << "#{label}: layout must be post" unless data["layout"] == "post"
  errors << "#{label}: kind must be one of #{NEWS_KINDS.join(', ')}" unless NEWS_KINDS.include?(data["kind"])
  errors << "#{label}: inline must be true or false" unless [true, false].include?(data["inline"])
  errors << "#{label}: related_posts must be true or false" unless [true, false].include?(data["related_posts"])

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
duplicate_keys = bib_entries.group_by { |entry| entry[:key] }.select { |_key, group| group.length > 1 }
duplicate_keys.each do |key, group|
  errors << "_bibliography/papers.bib: duplicate citation key #{key.inspect} at lines #{group.map { |entry| entry[:line] }.join(', ')}"
end

missing_links = []
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

  primary = unwrap_bib_value(fields["cate_primary"]&.last)
  errors << "#{label}: cate_primary must be one of #{BIB_CATEGORIES.join(', ')}" if present?(primary) && !BIB_CATEGORIES.include?(primary)

  secondary = unwrap_bib_value(fields["cate_secondary"]&.last)
  allowed_secondary = BIB_CATEGORIES + ["none"]
  errors << "#{label}: cate_secondary must be one of #{allowed_secondary.join(', ')}" if present?(secondary) && !allowed_secondary.include?(secondary)

  %w[bibtex_show selected].each do |field|
    value = unwrap_bib_value(fields[field]&.last)
    errors << "#{label}: #{field} must be true or false" if present?(value) && !%w[true false].include?(value)
  end

  missing_links << entry[:key] unless fields.key?("html") || fields.key?("doi")
end

warnings << "#{missing_links.length} historical bibliography entries have no html or doi link" if missing_links.any?

if warnings.any?
  puts "Warnings:"
  warnings.each { |warning| puts "  - #{warning}" }
end

if errors.any?
  warn "Content validation failed with #{errors.length} error#{errors.length == 1 ? '' : 's'}:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

puts "Content validation passed: #{people_files.length} people, #{cv_files.length} CV files, #{news_files.length} news items, #{bib_entries.length} publications."
