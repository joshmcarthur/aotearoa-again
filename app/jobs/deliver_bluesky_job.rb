class DeliverBlueskyJob < DeliveryJob
  def self.channel = "bluesky"

  retry_delivery_on Bluesky::Client::Error

  private

  def deliver(edition, delivery)
    unless edition.distribution_image.attached?
      delivery.fail!("Share image missing")
      return
    end

    document_ref = StandardSite::DocumentPublisher.call(edition, delivery)
    publication_ref = {
      uri: AppConfig.bluesky_publication_uri,
      cid: AppConfig.bluesky_publication_cid
    }
    if publication_ref.values.any?(&:blank?)
      delivery.fail!("Bluesky publication not configured")
      return
    end

    copy = edition.copy
    bytes = edition.distribution_image.download
    content_type = edition.distribution_image.content_type.presence || "image/jpeg"
    client = Bluesky::Client.new
    thumb_blob = client.upload_blob(bytes, content_type: content_type)

    post_ref = client.publish_edition_post(
      text: copy.bluesky_post_text,
      uri: edition.public_url,
      title: copy.title,
      description: copy.caption.to_s.truncate(300),
      thumb_blob: thumb_blob,
      document_ref: document_ref,
      publication_ref: publication_ref
    )

    delivery.merge_metadata!(bluesky_post_uri: post_ref[:uri])
    succeed_unless_done!(delivery, external_id: post_ref[:uri])
  end
end
