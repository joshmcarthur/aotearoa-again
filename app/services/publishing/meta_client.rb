require "faraday"
require "json"

module Publishing
  class MetaClient
    BASE_URL = "https://graph.facebook.com/v21.0".freeze

    class Error < StandardError; end

    def initialize(
      access_token: AppConfig.meta_page_access_token,
      instagram_user_id: AppConfig.meta_instagram_user_id,
      page_id: AppConfig.meta_page_id,
      http: nil
    )
      raise Error, "Meta page access token missing" if access_token.blank?

      @access_token = access_token
      @instagram_user_id = instagram_user_id
      @page_id = page_id
      @http = http || Faraday.new(url: BASE_URL) do |f|
        f.request :url_encoded
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    # Two-step Instagram Content Publishing API: create container, then publish.
    # Returns the published media id.
    def publish_instagram_photo(image_url:, caption:, alt_text: nil)
      raise Error, "Instagram not configured" if @instagram_user_id.blank?

      creation_id = create_instagram_media_container(
        image_url: image_url,
        caption: caption,
        alt_text: alt_text
      )
      publish_instagram_media(creation_id)
    end

    # One-step Facebook Page photos API. Returns the published photo/post id.
    def publish_facebook_photo(image_url:, caption:)
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

    private

    def create_instagram_media_container(image_url:, caption:, alt_text:)
      params = {
        image_url: image_url,
        caption: caption,
        access_token: @access_token
      }
      params[:alt_text] = alt_text if alt_text.present?

      response = @http.post("#{@instagram_user_id}/media", params)
      payload = JSON.parse(response.body)
      id = payload["id"]
      raise Error, "Instagram media container missing id: #{payload.inspect}" if id.blank?

      id
    rescue Faraday::Error => e
      raise Error, "Instagram media create failed: #{e.message}"
    end

    def publish_instagram_media(creation_id)
      response = @http.post(
        "#{@instagram_user_id}/media_publish",
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
