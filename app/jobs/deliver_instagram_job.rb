class DeliverInstagramJob < DeliveryJob
  def self.channel = "instagram"

  retry_delivery_on Instagram::Client::Error

  private

  def deliver(edition, delivery)
    image_url = edition.share_image_url
    unless image_url
      delivery.fail!("Share image missing")
      return
    end

    media_id = Instagram::Client.new.publish_photo(
      image_url: image_url,
      caption: edition.copy.instagram_caption,
      alt_text: edition.copy.alt_text
    )
    succeed_unless_done!(delivery, external_id: media_id.to_s)
  end
end
