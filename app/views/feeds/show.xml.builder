atom_feed(language: "en-NZ", root_url: root_url, url: feed_url) do |feed|
  feed.title("Aotearoa, Again")
  feed.updated(@editions.first&.published_at || Time.current)
  feed.subtitle("Daily photographs from the Alexander Turnbull Library, seen again in colour.")

  @editions.each do |edition|
    copy = edition.copy
    feed.entry(edition, url: edition_url(edition), id: edition_url(edition), published: edition.publish_on.to_time, updated: edition.updated_at) do |entry|
      entry.title(copy.title)
      entry.summary(copy.rss_summary, type: "text")
      image = edition.variant.distribution_image
      if image.attached?
        entry.link(rel: "enclosure", type: image.content_type, href: edition_share_image_url(edition))
      end
      entry.author do |author|
        author.name(edition.source_item.content_partner.presence || "Alexander Turnbull Library")
      end
    end
  end
end
