module Digitalnz
  class PartnerFilter
    TURNBULL = "Alexander Turnbull Library".freeze
    EXTRA_ALLOW = [
      "MOTAT",
      "Puke Ariki"
    ].freeze

    DENY = [
      /inaturalist/i,
      /figure\.nz/i,
      /figshare/i,
      /\btrove\b/i,
      /digital public library/i,
      /europeana/i,
      /british library/i,
      /museums victoria/i,
      /australian national maritime/i,
      /state library/i,
      /national archives uk/i,
      /deutsche digitale/i,
      /\buniversity\b/i,
      /\ANational Library of New Zealand\z/i,
      /art gallery/i,
      /theological/i,
      /\bcollege\b/i,
      /parliamentary/i,
      /landcare/i
    ].freeze

    ALLOW = [
      /council/i,
      /museum/i,
      /libraries/i,
      /city library/i,
      /district librar/i,
      /public librar/i,
      /\bLibrary\b/
    ].freeze

    def self.allowed?(name)
      new(name).allowed?
    end

    def initialize(name)
      @name = name.to_s.strip
    end

    def allowed?
      return false if @name.blank?
      return true if @name == TURNBULL
      return true if EXTRA_ALLOW.any? { |extra| extra.casecmp?(@name) }
      return false if DENY.any? { |pattern| @name.match?(pattern) }

      ALLOW.any? { |pattern| @name.match?(pattern) }
    end
  end
end
