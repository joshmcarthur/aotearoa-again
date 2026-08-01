class DeliverYoutubeShortJob < DeliveryJob
  def self.channel = "youtube_short"

  retry_delivery_on Youtube::Client::Error

  private

  def deliver(edition, delivery)
    unless edition.share_video.attached?
      delivery.fail!("Share video missing")
      return
    end

    video_id = Youtube::Client.new.publish_short(
      video_io: StringIO.new(edition.share_video.download),
      title: edition.copy.youtube_title,
      description: edition.copy.youtube_description
    )
    succeed_unless_done!(delivery, external_id: video_id.to_s)
  end
end
