class ComposeShareVideoJob
  # On-screen NatLib acknowledgement rows for the letterboxed short.
  module MetaRows
    Row = Data.define(:text, :primary)

    module_function

    # Matches editions/show `.aa-plate-date`: "Edition · {long date}", uppercased in CSS.
    def edition_label(edition)
      "Edition · #{I18n.l(edition.publish_on, format: :long)}".upcase
    end

    def for_source(source_item, copy)
      rows = []
      if source_item.display_date.present?
        rows << Row.new(text: source_item.display_date.to_s, primary: true)
      end
      partner = source_item.content_partner.presence || "Alexander Turnbull Library"
      creator = source_item.creator.to_s.strip
      credit = if creator.present? && !creator.match?(/\Anot specified\z/i)
        "#{partner} · #{creator}"
      else
        partner
      end
      rows << Row.new(text: credit, primary: true)
      if source_item.record_url.present?
        host_path = source_item.record_url.to_s.sub(%r{\Ahttps?://}i, "")
        rows << Row.new(text: "#{host_path} · via DigitalNZ", primary: true)
      else
        rows << Row.new(text: "via DigitalNZ", primary: true)
      end
      if source_item.rights_text.present?
        rows << Row.new(text: source_item.rights_text.to_s.strip, primary: false)
      end
      rows << Row.new(text: copy.ai_notice, primary: false)
      rows
    end
  end
end
