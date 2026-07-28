module Editions
  class Copy
    AI_NOTICE = "AI colourised — colours are interpretive.".freeze
    INSTAGRAM_CAPTION_LIMIT = 2200

    def initialize(source_item, edition: nil, variant: nil)
      @source_item = source_item
      @edition = edition
      @variant = variant || edition&.variant
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
      parts = [ AI_NOTICE ]
      return parts.join if @variant.nil?

      parts << "Model: #{@variant.model.name}."
      parts << "Generated #{I18n.l(@variant.created_at.to_date, format: :long)}."
      if @edition
        parts << "Reviewed #{I18n.l(@edition.created_at.to_date, format: :long)}."
      end
      parts.join(" ")
    end

    def rss_summary
      [ caption, attribution_text, ai_notice ].compact.join("\n\n")
    end

    # Shared narrative used by email and Instagram (title / image / link formatting differ).
    def body_text
      parts = []
      parts << caption if caption.present?
      meta = []
      meta << @source_item.display_date if @source_item.display_date.present?
      meta << @source_item.placename if @source_item.placename.present?
      parts << meta.join(" · ") if meta.any?
      parts << "" if parts.any?
      parts << attribution_text
      parts.join("\n")
    end

    def email_markdown(edition_url:, image_url: nil)
      parts = []
      parts << "# #{title}"
      parts << ""
      if image_url.present?
        parts << "[![#{title}](#{image_url})](#{edition_url})"
      end
      parts << ""
      parts << body_text
      parts << ""
      parts << "_#{ai_notice}_"
      parts << ""
      parts << "[View this plate](#{edition_url})"
      parts.join("\n")
    end

    # Same narrative as email, plain text for Instagram (≤ 2,200 chars).
    def instagram_caption(edition_url:)
      social_caption(edition_url: edition_url).truncate(INSTAGRAM_CAPTION_LIMIT)
    end

    # Same narrative as Instagram; Facebook allows a much longer message.
    def facebook_caption(edition_url:)
      social_caption(edition_url: edition_url)
    end

    def alt_text
      [ title, caption ].compact.join(". ").truncate(1000)
    end

    private

    def social_caption(edition_url:)
      [
        title,
        "",
        body_text,
        "",
        ai_notice,
        "",
        edition_url.to_s
      ].join("\n")
    end

    def fallback_caption
      [ title, @source_item.display_date, @source_item.placename ].compact.join(" — ")
    end
  end
end
