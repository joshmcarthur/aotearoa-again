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
        @copy ||= Editions::Copy.new(edition.source_item)
      end

      def public_edition_url
        Rails.application.routes.url_helpers.edition_url(
          edition,
          host: AppConfig.app_host,
          protocol: AppConfig.protocol
        )
      end

      def share_image_url
        return unless edition.variant.distribution_image.attached?

        edition_media_url(:edition_share_image_url)
      end

      def share_video_url
        return unless edition.variant.share_video.attached?

        edition_media_url(:edition_share_video_url)
      end

      def composite_image_url
        return unless edition.variant.archive_image.attached?

        edition_media_url(:edition_composite_image_url)
      end

      def edition_media_url(helper_name)
        Rails.application.routes.url_helpers.public_send(
          helper_name,
          edition,
          host: AppConfig.app_host,
          protocol: AppConfig.protocol
        )
      end

      def instagram_gated?
        AppConfig.instagram_configured? && edition.source_item.commercial_use?
      end

      def facebook_gated?
        AppConfig.facebook_configured? && edition.source_item.commercial_use?
      end
    end
  end
end
