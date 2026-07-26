require "faraday"
require "json"

module Publishing
  class InstagramClient
    BASE_URL = "https://graph.facebook.com/v21.0".freeze

    class Error < StandardError; end

    def initialize(
      access_token: AppConfig.instagram_access_token,
      user_id: AppConfig.instagram_user_id,
      http: nil
    )
      raise Error, "Instagram not configured" if access_token.blank? || user_id.blank?

      @access_token = access_token
      @user_id = user_id
      @http = http || Faraday.new(url: BASE_URL) do |f|
        f.request :url_encoded
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    # Two-step Content Publishing API: create container, then publish.
    # Returns the published media id.
    def publish_photo(image_url:, caption:, alt_text: nil)
      creation_id = create_media_container(
        image_url: image_url,
        caption: caption,
        alt_text: alt_text
      )
      publish_media(creation_id)
    end

    private

    def create_media_container(image_url:, caption:, alt_text:)
      params = {
        image_url: image_url,
        caption: caption,
        access_token: @access_token
      }
      params[:alt_text] = alt_text if alt_text.present?

      response = @http.post("#{@user_id}/media", params)
      payload = JSON.parse(response.body)
      id = payload["id"]
      raise Error, "Instagram media container missing id: #{payload.inspect}" if id.blank?

      id
    rescue Faraday::Error => e
      raise Error, "Instagram media create failed: #{e.message}"
    end

    def publish_media(creation_id)
      response = @http.post(
        "#{@user_id}/media_publish",
        creation_id: creation_id,
        access_token: @access_token
      )
      payload = JSON.parse(response.body)
      id = payload["id"]
      raise Error, "Instagram media publish missing id: #{payload.inspect}" if id.blank?

      id
    rescue Faraday::Error => e
      raise Error, "Instagram media publish failed: #{e.message}"
    end
  end
end
