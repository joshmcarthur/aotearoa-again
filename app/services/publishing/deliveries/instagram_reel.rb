module Publishing
  module Deliveries
    class InstagramReel < Base
      def self.channel = "instagram_reel"

      def self.optional? = true

      def call
        unless instagram_gated?
          skip_delivery
          return
        end

        delivery = find_or_create_delivery
        return if already_succeeded?(delivery)

        video_url = share_video_url
        unless video_url
          soft_fail!(delivery, "Share video missing")
          return
        end

        media_id = client.publish_reel(
          video_url: video_url,
          caption: copy.instagram_caption,
          cover_url: share_image_url,
          share_to_feed: false
        )
        delivery.succeed!(external_id: media_id.to_s)
      rescue Instagram::Client::Error => e
        soft_fail!(delivery, e.message)
      end

      private

      def client
        @client ||= Instagram::Client.new
      end

      def soft_fail!(delivery, message)
        delivery.fail!(message)
        AdminMailer.delivery_failed(edition).deliver_later
      end
    end
  end
end
