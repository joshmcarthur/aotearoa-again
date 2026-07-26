module Digitalnz
  class RightsFilter
    REQUIRED_USAGE = "Modify".freeze
    # NatLib free-download / Meta-upload-eligible ATL subset.
    COMMERCIAL_USAGE = "Use commercially".freeze
    PREFERRED_USAGE = "Share".freeze
    COLOUR_KEYWORDS = /\b(colour|color|coloured|colored|hand[- ]?coloured|hand[- ]?colored)\b/i

    def self.acceptable?(record)
      new(record).acceptable?
    end

    def initialize(record)
      @record = record.is_a?(Hash) ? record.with_indifferent_access : record
    end

    def acceptable?
      rights.present? &&
        usage_includes?(REQUIRED_USAGE) &&
        commercial_use? &&
        !colour_keyword_hit?
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

    def usage_includes?(value)
      usage_list.any? { |u| u.casecmp?(value) }
    end

    def colour_keyword_hit?
      text = [ @record[:title], @record[:description] ].compact.join(" ")
      text.match?(COLOUR_KEYWORDS)
    end
  end
end
