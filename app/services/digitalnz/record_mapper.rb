module Digitalnz
  class RecordMapper
    def self.to_source_attributes(record)
      new(record).to_source_attributes
    end

    def initialize(record)
      @record = record.with_indifferent_access
    end

    def to_source_attributes
      filter = RightsFilter.new(@record)
      {
        digitalnz_id: @record[:id].to_s,
        title: @record[:title].presence || "Untitled photograph",
        description: Array(@record[:description]).join("\n\n").presence,
        display_date: @record[:display_date].presence || Array(@record[:date]).first,
        year: extract_year,
        placename: Array(@record[:placename]).first,
        creator: Array(@record[:creator]).first,
        content_partner: Array(@record[:content_partner]).first,
        rights_text: filter.rights,
        usage_flags: filter.usage_list,
        meta_upload_eligible: MetaEligibility.eligible?(@record),
        record_url: canonical_record_url,
        image_url: preferred_image_url,
        dedupe_key: "digitalnz:#{@record[:id]}",
        raw_metadata: @record.to_h
      }
    end

    private

    def extract_year
      year = Array(@record[:year]).first || Array(@record[:date]).first
      Integer(year.to_s[/\d{4}/]) if year
    rescue ArgumentError, TypeError
      nil
    end

    def canonical_record_url
      @record[:landing_url].presence ||
        @record[:source_url].presence ||
        "https://digitalnz.org/records/#{@record[:id]}"
    end

    def preferred_image_url
      large = Array(@record[:large_thumbnail_url]).first
      thumb = Array(@record[:thumbnail_url]).first
      object = Array(@record[:object_url]).compact.find { |url| url.to_s.match?(/\.(jpe?g|png|gif|webp)(\?|$)/i) }
      object.presence || large.presence || thumb.presence
    end
  end
end
