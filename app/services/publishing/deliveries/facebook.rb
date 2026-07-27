module Publishing
  module Deliveries
    class Facebook < Base
      def self.channel = "facebook"

      def call
        unless facebook_gated?
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

        post_id = meta_client.publish_facebook_photo(
          image_url: image_url,
          caption: copy.facebook_caption(edition_url: public_edition_url)
        )
        delivery.succeed!(external_id: post_id.to_s)
      rescue Meta::Client::Error => e
        delivery.fail!(e.message)
      end
    end
  end
end
