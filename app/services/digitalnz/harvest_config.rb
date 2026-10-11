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
      params = {}

      URI.decode_www_form(query_string).each do |raw_key, value|
        key = api_param_key(raw_key)
        next if key.blank? || SKIP_QUERY_KEYS.include?(key) || value.blank?

        params[key] = Array(params[key]) + [ value ]
      end

      params
    end

    # DigitalNZ cannot glob content_partner. Empty include = every partner in the query.
    def allowed_partner?(name)
      name = name.to_s.strip
      return false if name.blank?

      includes = Array(@data.dig(:include, :partners)).map(&:to_s)
      return true if includes.empty?

      includes.any? { |pattern| match_pattern?(pattern, name) }
    end

    private

    def load_file
      Rails.application.config_for(:digitalnz)
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

    def match_pattern?(pattern, value)
      if pattern.match?(/[*?]/)
        File.fnmatch?(pattern, value, File::FNM_CASEFOLD)
      else
        value.casecmp?(pattern)
      end
    end
  end
end
