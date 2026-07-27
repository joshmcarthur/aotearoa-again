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

        media_id = meta_client.publish_instagram_photo(
          image_url: image_url,
          caption: copy.instagram_caption(edition_url: public_edition_url),
          alt_text: copy.alt_text
        )
        delivery.succeed!(external_id: media_id.to_s)
      rescue Meta::Client::Error => e
        delivery.fail!(e.message)
      end
    end
  end
end
