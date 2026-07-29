require "faraday"
require "json"

module Facebook
  class Client
    BASE_URL = "https://graph.facebook.com/v21.0".freeze

    class Error < StandardError; end

    def initialize(
      access_token: AppConfig.meta_page_access_token,
      page_id: AppConfig.meta_page_id,
      http: nil
    )
      raise Error, "Meta page access token missing" if access_token.blank?

      @access_token = access_token
      @page_id = page_id
      @http = http || Faraday.new(url: BASE_URL) do |f|
        f.request :url_encoded
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    # One-step Facebook Page photos API. Returns the published photo/post id.
    def publish_photo(image_url:, caption:)
      raise Error, "Facebook not configured" if @page_id.blank?

      response = @http.post(
        "#{@page_id}/photos",
        url: image_url,
        caption: caption,
        access_token: @access_token
      )
      payload = JSON.parse(response.body)
      id = payload["id"].presence || payload["post_id"].presence
      raise Error, "Facebook photo publish missing id: #{payload.inspect}" if id.blank?

      id
    rescue Faraday::Error => e
      raise Error, "Facebook photo publish failed: #{e.message}"
    end
  end
end
