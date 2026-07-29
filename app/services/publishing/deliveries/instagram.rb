module Publishing
  module Deliveries
    class Instagram < Base
      def self.channel = "instagram"

      def call
        unless instagram_gated?
          skip_delivery
          return
        end

        delivery = find_or_create_delivery
        return if already_succeeded?(delivery)

        image_url = share_image_url
        unless image_url
          delivery.fail!("Share image missing")
          return
        end

        media_id = client.publish_photo(
          image_url: image_url,
          caption: copy.instagram_caption,
          alt_text: copy.alt_text
        )
        delivery.succeed!(external_id: media_id.to_s)
      rescue ::Instagram::Client::Error => e
        delivery.fail!(e.message)
      end

      private

      def client
        @client ||= ::Instagram::Client.new
      end
    end
  end
end
