module Publishing
  module Deliveries
    class Email < Base
      def self.channel = "email"

      def call
        delivery = find_or_create_delivery
        return if already_succeeded?(delivery)

        image_url = composite_image_url
        unless image_url
          delivery.fail!("Composite image missing")
          return
        end

        payload = buttondown_client.create_and_send(
          subject: copy.title,
          body: copy.email_markdown(edition_url: public_edition_url, image_url: image_url)
        )
        delivery.succeed!(external_id: payload["id"].to_s)
      rescue ButtondownClient::Error => e
        delivery.fail!(e.message)
      end
    end
  end
end
