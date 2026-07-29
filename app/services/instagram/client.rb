require "faraday"
require "json"

module Instagram
  class Client
    BASE_URL = "https://graph.facebook.com/v21.0".freeze
    REEL_POLL_INTERVAL_S = 5
    REEL_POLL_TIMEOUT_S = 5 * 60

    class Error < StandardError; end

    def initialize(
      access_token: AppConfig.meta_page_access_token,
      instagram_user_id: AppConfig.meta_instagram_user_id,
      http: nil,
      sleeper: ->(seconds) { sleep(seconds) },
      clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    )
      raise Error, "Meta page access token missing" if access_token.blank?

      @access_token = access_token
      @instagram_user_id = instagram_user_id
      @sleeper = sleeper
      @clock = clock
      @http = http || Faraday.new(url: BASE_URL) do |f|
        f.request :url_encoded
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    # Two-step Content Publishing API: create container, then publish.
    def publish_photo(image_url:, caption:, alt_text: nil)
      require_instagram!

      creation_id = create_photo_container(
        image_url: image_url,
        caption: caption,
        alt_text: alt_text
      )
      publish_media(creation_id)
    end

    # Three-step Reels publish: create REELS container, poll until FINISHED, publish.
    def publish_reel(video_url:, caption:, cover_url: nil, share_to_feed: false)
      require_instagram!

      creation_id = create_reel_container(
        video_url: video_url,
        caption: caption,
        cover_url: cover_url,
        share_to_feed: share_to_feed
      )
      wait_for_container(creation_id)
      publish_media(creation_id)
    end

    private

    def require_instagram!
      raise Error, "Instagram not configured" if @instagram_user_id.blank?
    end

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
      raise Error, "Instagram media container missing id: #{payload.inspect}" if id.blank?

      id
    rescue Faraday::Error => e
      raise Error, "Instagram media create failed: #{e.message}"
    end

    def create_reel_container(video_url:, caption:, cover_url:, share_to_feed:)
      params = {
        media_type: "REELS",
        video_url: video_url,
        caption: caption,
        share_to_feed: share_to_feed ? "true" : "false",
        access_token: @access_token
      }
      params[:cover_url] = cover_url if cover_url.present?

      response = @http.post("#{@instagram_user_id}/media", params)
      payload = JSON.parse(response.body)
      id = payload["id"]
      raise Error, "Instagram reel container missing id: #{payload.inspect}" if id.blank?

      id
    rescue Faraday::Error => e
      raise Error, "Instagram reel create failed: #{e.message}"
    end

    def wait_for_container(creation_id)
      deadline = @clock.call + REEL_POLL_TIMEOUT_S

      loop do
        status = container_status(creation_id)
        return if status == "FINISHED"
        raise Error, "Instagram reel processing failed (status=#{status})" if status == "ERROR"
        raise Error, "Instagram reel processing timed out" if @clock.call >= deadline

        @sleeper.call(REEL_POLL_INTERVAL_S)
      end
    end

    def container_status(creation_id)
      response = @http.get(
        creation_id.to_s,
        fields: "status_code",
        access_token: @access_token
      )
      payload = JSON.parse(response.body)
      status = payload["status_code"].to_s
      raise Error, "Instagram reel status missing: #{payload.inspect}" if status.blank?

      status
    rescue Faraday::Error => e
      raise Error, "Instagram reel status failed: #{e.message}"
    end

    def publish_media(creation_id)
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
