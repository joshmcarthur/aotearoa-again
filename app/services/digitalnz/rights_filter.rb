module Digitalnz
  class RightsFilter
    REQUIRED_USAGE = "Modify".freeze
    COMMERCIAL_USAGE = "Use commercially".freeze
    PREFERRED_USAGE = "Share".freeze
    COLOUR_KEYWORDS = /\b(colour|color|coloured|colored|hand[- ]?coloured|hand[- ]?colored)\b/i
    PORTRAIT_PATTERN = /\bportraits?\b/i
    REJECT_TYPE = /transparency|photograph\s+slide|watercolor|watercolour|specimen|poster|\bmaps?\b|artwork|art\s*work|\bcards?\b/i
    PEOPLE_TAGS = %w[men women children people persons crowds].freeze
    PEOPLE_SUBJECTS = [
      "Portraits",
      "portraits",
      "studio portraits",
      "Group portraits",
      "people",
      "Men",
      "Women",
      "Children"
    ].freeze
    EXTRA_PARTNERS = [ "MOTAT", "Puke Ariki" ].freeze
    PARTNER_ALLOW = /council|museum|library|libraries/i
    PARTNER_DENY = /digital public library|british library|museums victoria|australian national maritime|state library|\ANational Library of New Zealand\z|university|college|parliamentary|theological/i

    def self.allowed_partner?(name)
      name = name.to_s.strip
      return false if name.blank?
      return true if EXTRA_PARTNERS.any? { |extra| extra.casecmp?(name) }
      return false if name.match?(PARTNER_DENY)

      name.match?(PARTNER_ALLOW)
    end

    def self.acceptable?(record)
      new(record).acceptable?
    end

    def initialize(record)
      @record = record.is_a?(Hash) ? record.with_indifferent_access : record
    end

    def acceptable?
      self.class.allowed_partner?(partner) &&
        rights.present? &&
        usage_includes?(REQUIRED_USAGE) &&
        commercial_use? &&
        !colour_keyword_hit? &&
        photograph? &&
        !people_prominent?
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

    def usage_includes?(value)
      usage_list.any? { |u| u.casecmp?(value) }
    end

    def colour_keyword_hit?
      blob.match?(COLOUR_KEYWORDS)
    end

    def photograph?
      Array(@record[:dc_type]).none? { |type| type.to_s.match?(REJECT_TYPE) }
    end

    def people_prominent?
      return true if @record[:title].to_s.match?(PORTRAIT_PATTERN)

      tags.any? do |tag|
        PEOPLE_TAGS.include?(tag.to_s.strip.downcase) || tag.to_s.match?(PORTRAIT_PATTERN)
      end
    end

    def tags
      Array(@record[:subject]) + Array(@record[:dc_type])
    end

    def blob
      [
        @record[:title],
        @record[:description],
        Array(@record[:subject]).join(" "),
        Array(@record[:dc_type]).join(" ")
      ].compact.join(" ")
    end
  end
end
