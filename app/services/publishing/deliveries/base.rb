module Publishing
  module Deliveries
    class Base
      def self.channel
        raise NotImplementedError, "#{name} must define .channel"
      end

      def self.optional?
        false
      end

      def initialize(edition, client: nil)
        @edition = edition
        @client = client
      end

      def call
        raise NotImplementedError
      end

      private

      attr_reader :edition

      def channel
        self.class.channel
      end

      def find_or_create_delivery
        edition.deliveries.find_or_create_by!(channel: channel)
      end

      def skip_delivery
        delivery = edition.deliveries.find_by(channel: channel)
        return unless delivery
        return if delivery.status == "succeeded"

        delivery.destroy!
      end

      def already_succeeded?(delivery)
        delivery.status == "succeeded" && delivery.external_id.present?
      end

      def copy
        edition.copy
      end

      def public_edition_url
        edition.public_url
      end

      def share_image_url
        edition.share_image_url
      end

      def share_video_url
        edition.share_video_url
      end

      def composite_image_url
        edition.composite_image_url
      end

      def instagram_gated?
        Delivery.new(edition: edition, channel: "instagram").applicable?
      end

      def facebook_gated?
        Delivery.new(edition: edition, channel: "facebook").applicable?
      end
    end
  end
end
