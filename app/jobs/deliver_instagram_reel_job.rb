class DeliverInstagramReelJob < DeliveryJob
  def self.channel = "instagram_reel"

  retry_delivery_on Instagram::Client::Error

  private

  def deliver(edition, delivery)
    video_url = edition.share_video_url
    unless video_url
      delivery.fail!("Share video missing")
      return
    end

    media_id = Instagram::Client.new.publish_reel(
      video_url: video_url,
      caption: edition.copy.instagram_caption,
      cover_url: edition.share_image_url,
      share_to_feed: false
    )
    succeed_unless_done!(delivery, external_id: media_id.to_s)
  end
end
