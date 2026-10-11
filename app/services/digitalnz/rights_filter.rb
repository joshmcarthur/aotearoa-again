module Digitalnz
  class RightsFilter
    COMMERCIAL_USAGE = "Use commercially".freeze

    def self.allowed_partner?(name, config: HarvestConfig.current)
      config.allowed_partner?(name)
    end

    def self.acceptable?(record, config: HarvestConfig.current)
      new(record, config: config).acceptable?
    end

    def initialize(record, config: HarvestConfig.current)
      @record = record.is_a?(Hash) ? record.with_indifferent_access : record
      @config = config
    end

    def acceptable?
      @config.allowed_partner?(partner) &&
        rights.present? &&
        required_usage_met? &&
        !@config.excluded_record?(@record)
    end

    def usage_list
      Array(@record[:usage]).map(&:to_s)
    end

    def rights
      Array(@record[:rights]).map(&:to_s).reject(&:blank?).join("; ").presence ||
        @record[:rights_url].presence
    end

    def commercial_use?
      usage_includes?(COMMERCIAL_USAGE)
    end

    private

    def partner
      Array(@record[:content_partner]).first
    end

    def required_usage_met?
      Array(@config.search_params["and[usage]"]).all? { |value| usage_includes?(value) }
    end

    def usage_includes?(value)
      usage_list.any? { |u| u.casecmp?(value) }
    end
  end
end
