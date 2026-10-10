module Digitalnz
  class RecordFilter
    NON_PHOTO_TYPE = /\b(
      transparency | photograph\s+slide | watercolor | watercolour | specimen |
      poster | maps? | artwork | art\s*work | cards? | clothing |
      textiles? | physical\s+object | equipment | documents? | figure
    )\b/ix

    PEOPLE_EXACT = %w[
      men women children people persons crowds soldiers airmen
    ].freeze

    PORTRAIT_PATTERN = /\bportraits?\b/i

    def self.acceptable?(record)
      new(record).acceptable?
    end

    def initialize(record)
      @record = record.is_a?(Hash) ? record.with_indifferent_access : record
      @rights = RightsFilter.new(@record)
    end

    def acceptable?
      PartnerFilter.allowed?(partner) &&
        @rights.acceptable? &&
        photograph? &&
        !people_prominent?
    end

    private

    def partner
      Array(@record[:content_partner]).first
    end

    def photograph?
      types = Array(@record[:dc_type]).map(&:to_s)
      return false if types.any? { |type| type.match?(NON_PHOTO_TYPE) }

      true
    end

    def people_prominent?
      return true if @record[:title].to_s.match?(PORTRAIT_PATTERN)

      tags.any? { |tag| people_tag?(tag) }
    end

    def tags
      Array(@record[:subject]) + Array(@record[:dc_type])
    end

    def people_tag?(value)
      normalized = value.to_s.strip.downcase
      return true if PEOPLE_EXACT.include?(normalized)
      return true if normalized.match?(PORTRAIT_PATTERN)

      false
    end
  end
end
