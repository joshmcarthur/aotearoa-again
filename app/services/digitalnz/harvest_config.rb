module Digitalnz
  class HarvestConfig
    SKIP_QUERY_KEYS = %w[page per_page utf8 facets facets_per_page fields].freeze

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
      params = parse_query
      exact_subjects = exclude_list(:subjects).reject { |pattern| glob?(pattern) }
      if exact_subjects.any?
        params["without[subject]"] = (Array(params["without[subject]"]) + exact_subjects).uniq { |value| value.downcase }
      end
      params
    end

    # Whitelist then blacklist: must match include (if any), then exclude wins.
    def allowed_partner?(name)
      name = name.to_s.strip
      return false if name.blank?

      includes = include_list(:partners)
      return false if includes.any? && !matches_any?(name, includes)
      return false if matches_any?(name, exclude_list(:partners))

      true
    end

    def excluded_record?(record)
      record = record.with_indifferent_access
      return true if title_excluded?(record[:title])
      return true if any_value_matches?(record[:subject], exclude_list(:subjects))
      return true if any_value_matches?(record[:dc_type], exclude_list(:types))

      false
    end

    private

    def load_file
      Rails.application.config_for(:digitalnz)
    end

    def parse_query
      params = {}

      URI.decode_www_form(query_string).each do |raw_key, value|
        key = api_param_key(raw_key)
        next if key.blank? || SKIP_QUERY_KEYS.include?(key) || value.blank?

        params[key] = Array(params[key]) + [ value ]
      end

      params
    end

    def query_string
      raw = @data[:query].to_s.strip
      raw = URI.parse(raw).query.to_s if raw.match?(%r{\A[a-z][a-z0-9+\-.]*://}i)
      raw.delete_prefix("?")
    end

    def api_param_key(raw_key)
      case raw_key.to_s
      when /^(i|and|or|without)\[([^\]]+)\](?:\[\])?$/
        namespace = $1 == "i" ? "and" : $1
        "#{namespace}[#{$2}]"
      when "text"
        "text"
      end
    end

    def include_list(field)
      Array(@data.dig(:include, field)).map(&:to_s)
    end

    def exclude_list(field)
      Array(@data.dig(:exclude, field)).map(&:to_s)
    end

    def title_excluded?(title)
      haystack = title.to_s.downcase
      Array(@data.dig(:exclude, :title_contains)).any? { |needle| haystack.include?(needle.to_s.downcase) }
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
