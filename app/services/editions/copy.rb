module Editions
  class Copy
    AI_NOTICE = "AI colourised — colours are interpretive.".freeze

    def initialize(source_item)
      @source_item = source_item
    end

    def title
      @source_item.title
    end

    def caption
      description.presence || fallback_caption
    end

    def description
      @source_item.description.to_s.strip.presence
    end

    def attribution_lines
      lines = []
      partner = @source_item.content_partner.presence || "Alexander Turnbull Library"
      lines << partner
      lines << "Creator: #{@source_item.creator}" if @source_item.creator.present?
      lines << "Rights: #{@source_item.rights_text}" if @source_item.rights_text.present?
      lines << "Source record: #{@source_item.record_url}"
      lines << "via DigitalNZ"
      lines
    end

    def attribution_text
      attribution_lines.join("\n")
    end

    def ai_notice
      AI_NOTICE
    end

    def rss_summary
      [ caption, attribution_text, ai_notice ].compact.join("\n\n")
    end

    def email_markdown(edition_url:, archive_url:, image_url: nil)
      parts = []
      parts << "# #{title}"
      parts << ""
      parts << "![#{title}](#{image_url})" if image_url.present?
      parts << ""
      parts << caption if caption.present?
      parts << ""
      meta = []
      meta << @source_item.display_date if @source_item.display_date.present?
      meta << @source_item.placename if @source_item.placename.present?
      parts << meta.join(" · ") if meta.any?
      parts << ""
      parts << attribution_text
      parts << ""
      parts << "_#{ai_notice}_"
      parts << ""
      parts << "[View this plate](#{edition_url})"
      parts << ""
      parts << "[View the archive](#{archive_url})"
      parts.join("\n")
    end

    private

    def fallback_caption
      [ title, @source_item.display_date, @source_item.placename ].compact.join(" — ")
    end
  end
end
