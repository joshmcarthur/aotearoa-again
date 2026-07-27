require "faraday"

module Publishing
  module Meta
    class Client
      BASE_URL = "https://graph.facebook.com/v21.0".freeze

      class Error < StandardError; end

      def initialize(
        access_token: AppConfig.meta_page_access_token,
        instagram_user_id: AppConfig.meta_instagram_user_id,
        page_id: AppConfig.meta_page_id,
        http: nil
      )
        raise Error, "Meta page access token missing" if access_token.blank?

        @http = http || Faraday.new(url: BASE_URL) do |f|
          f.request :url_encoded
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end
        @instagram = Instagram.new(
          http: @http,
          access_token: access_token,
          instagram_user_id: instagram_user_id
        )
        @facebook = Facebook.new(
          http: @http,
          access_token: access_token,
          page_id: page_id
        )
      end

      def publish_instagram_photo(image_url:, caption:, alt_text: nil)
        @instagram.publish_photo(image_url: image_url, caption: caption, alt_text: alt_text)
      end

      def publish_facebook_photo(image_url:, caption:)
        @facebook.publish_photo(image_url: image_url, caption: caption)
      end
    end
  end
end
