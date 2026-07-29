class DeliverEmailJob < DeliveryJob
  def self.channel = "email"

  retry_delivery_on Buttondown::Client::Error

  private

  def deliver(edition, delivery)
    image_url = edition.composite_image_url
    unless image_url
      delivery.fail!("Composite image missing")
      return
    end

    payload = Buttondown::Client.new.create_and_send(
      subject: edition.copy.title,
      body: edition.copy.email_markdown(image_url: image_url)
    )
    succeed_unless_done!(delivery, external_id: payload["id"].to_s)
  end
end
