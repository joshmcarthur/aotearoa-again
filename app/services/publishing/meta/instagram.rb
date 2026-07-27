require "json"

module Publishing
  module Meta
    class Instagram
      def initialize(http:, access_token:, instagram_user_id:)
        @http = http
        @access_token = access_token
        @instagram_user_id = instagram_user_id
      end

      # Two-step Content Publishing API: create container, then publish.
      def publish_photo(image_url:, caption:, alt_text: nil)
        raise Client::Error, "Instagram not configured" if @instagram_user_id.blank?

        creation_id = create_photo_container(
          image_url: image_url,
          caption: caption,
          alt_text: alt_text
        )
        publish_media(creation_id)
      end

      private

      def create_photo_container(image_url:, caption:, alt_text:)
        params = {
          image_url: image_url,
          caption: caption,
          access_token: @access_token
        }
        params[:alt_text] = alt_text if alt_text.present?

        response = @http.post("#{@instagram_user_id}/media", params)
        payload = JSON.parse(response.body)
        id = payload["id"]
        raise Client::Error, "Instagram media container missing id: #{payload.inspect}" if id.blank?

        id
      rescue Faraday::Error => e
        raise Client::Error, "Instagram media create failed: #{e.message}"
      end

      def publish_media(creation_id)
        response = @http.post(
          "#{@instagram_user_id}/media_publish",
          creation_id: creation_id,
          access_token: @access_token
        )
        payload = JSON.parse(response.body)
        id = payload["id"]
        raise Client::Error, "Instagram media publish missing id: #{payload.inspect}" if id.blank?

        id
      rescue Faraday::Error => e
        raise Client::Error, "Instagram media publish failed: #{e.message}"
      end
    end
  end
end
