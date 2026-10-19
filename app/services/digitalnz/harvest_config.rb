module Digitalnz
  class HarvestConfig
    SKIP_QUERY_KEYS = %w[page per_page utf8 facets facets_per_page fields].freeze
    FILTER_KEY = /\A(i|and|or|without)\[([^\]]+)\](?:\[\])?\z/
    PREFILTERS = {
      subjects: "without[subject]",
      partners: "without[content_partner]",
      types: "without[dc_type]"
    }.freeze
    RECORD_FIELDS = {
      title: :title,
      description: :description,
      subjects: :subject,
      types: :dc_type
    }.freeze

    def self.current
      @current ||= new
    end

    def self.reset!
      @current = nil
    end

    def initialize(data = nil)
      @data = (data || load_file).with_indifferent_access
    end

    def search_params
      params = flatten_search_params(permitted_query_params)
      apply_prefilters!(params)
      params
    end

    # Allow then deny: must match include (if any), then exclude wins.
    # Empty include means the search params already define the partner pool.
    def allowed_partner?(name)
      name = name.to_s.strip
      includes = include_list(:partners)
      return false if name.present? && matches_any?(name, exclude_list(:partners))
      return true if includes.empty?
      return false if name.blank?

      matches_any?(name, includes)
    end

    def excluded_record?(record)
      record = record.with_indifferent_access
      RECORD_FIELDS.any? do |field, key|
        any_value_matches?(record[key], exclude_list(field))
      end
    end

    private

    def load_file
      Rails.application.config_for(:digitalnz)
    end

    def url_query_string
      raw = @data[:url].to_s.strip
      uri = URI.parse(raw)
      uri.scheme ? uri.query.to_s : raw.delete_prefix("?")
    rescue URI::InvalidURIError
      raw.delete_prefix("?")
    end

    def permitted_query_params
      nested = merge_nested_params(
        nest_query_params(Rack::Utils.parse_query(url_query_string)),
        nest_query_params(Hash(@data[:params]))
      )

      ActionController::Parameters.new(nested)
        .except(*SKIP_QUERY_KEYS)
        .slice(:text, :i, :and, :or, :without)
        .permit(:text, text: [], i: {}, and: {}, or: {}, without: {})
        .to_h
    end

    def nest_query_params(hash)
      nested = {}

      hash.each do |raw_key, value|
        values = Array(value).map(&:to_s).reject(&:blank?)
        next if values.empty?

        key = raw_key.to_s
        if (match = FILTER_KEY.match(key))
          namespace, field = match.captures
          fields = nested[namespace] ||= {}
          fields[field] = Array(fields[field]) + values
        else
          nested[key] = Array(nested[key]) + values
        end
      end

      nested
    end

    def merge_nested_params(base, extra)
      extra.each_with_object(base.deep_dup) do |(key, value), memo|
        if value.is_a?(Hash)
          memo[key] = Hash(memo[key]).merge(value) { |_field, left, right| Array(left) + Array(right) }
        else
          memo[key] = Array(memo[key]) + Array(value)
        end
      end
    end

    def flatten_search_params(permitted)
      permitted = permitted.with_indifferent_access
      params = {}

      text = Array(permitted[:text]).map(&:to_s).reject(&:blank?)
      params["text"] = text if text.any?

      and_fields = Hash(permitted[:i]).merge(Hash(permitted[:and])) { |_field, left, right| Array(left) + Array(right) }
      flatten_namespace!(params, "and", and_fields)
      flatten_namespace!(params, "or", permitted[:or])
      flatten_namespace!(params, "without", permitted[:without])
      params
    end

    def flatten_namespace!(params, namespace, fields)
      Hash(fields).each do |field, values|
        values = Array(values).map(&:to_s).reject(&:blank?)
        next if values.empty?

        params["#{namespace}[#{field}]"] = values
      end
    end

    def apply_prefilters!(params)
      PREFILTERS.each do |field, key|
        exact = exclude_list(field).reject { |pattern| glob?(pattern) }
        next if exact.empty?

        params[key] = (Array(params[key]) + exact).uniq
      end
    end

    def include_list(field)
      Array(@data.dig(:include, field)).map(&:to_s)
    end

    def exclude_list(field)
      Array(@data.dig(:exclude, field)).map(&:to_s)
    end

    def any_value_matches?(values, patterns)
      Array(values).any? { |value| matches_any?(value.to_s, patterns) }
    end

    def matches_any?(value, patterns)
      patterns.any? { |pattern| match_pattern?(pattern, value) }
    end

    def match_pattern?(pattern, value)
      if glob?(pattern)
        File.fnmatch?(pattern, value, File::FNM_CASEFOLD)
      else
        value.casecmp?(pattern)
      end
    end

    def glob?(pattern)
      pattern.match?(/[*?]/)
    end
  end
end
