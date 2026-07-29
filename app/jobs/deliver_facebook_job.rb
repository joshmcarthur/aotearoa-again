class DeliverFacebookJob < DeliveryJob
  def self.channel = "facebook"

  retry_delivery_on Facebook::Client::Error

  private

  def deliver(edition, delivery)
    image_url = edition.share_image_url
    unless image_url
      delivery.fail!("Share image missing")
      return
    end

    post_id = Facebook::Client.new.publish_photo(
      image_url: image_url,
      caption: edition.copy.facebook_caption
    )
    succeed_unless_done!(delivery, external_id: post_id.to_s)
  end
end
