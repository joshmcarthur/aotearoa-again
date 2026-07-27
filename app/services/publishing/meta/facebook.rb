require "json"

module Publishing
  module Meta
    class Facebook
      def initialize(http:, access_token:, page_id:)
        @http = http
        @access_token = access_token
        @page_id = page_id
      end

      # One-step Facebook Page photos API. Returns the published photo/post id.
      def publish_photo(image_url:, caption:)
        raise Client::Error, "Facebook not configured" if @page_id.blank?

        response = @http.post(
          "#{@page_id}/photos",
          url: image_url,
          caption: caption,
          access_token: @access_token
        )
        payload = JSON.parse(response.body)
        id = payload["id"].presence || payload["post_id"].presence
        raise Client::Error, "Facebook photo publish missing id: #{payload.inspect}" if id.blank?

        id
      rescue Faraday::Error => e
        raise Client::Error, "Facebook photo publish failed: #{e.message}"
      end
    end
  end
end
