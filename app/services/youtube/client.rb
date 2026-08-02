require "faraday"
require "json"

module Youtube
  class Client
    OAUTH_URL = "https://oauth2.googleapis.com".freeze
    API_URL = "https://www.googleapis.com".freeze
    UPLOAD_URL = "https://www.googleapis.com/upload/youtube/v3".freeze

    class Error < StandardError; end

    def initialize(
      client_id: AppConfig.youtube_client_id,
      client_secret: AppConfig.youtube_client_secret,
      refresh_token: AppConfig.youtube_refresh_token,
      oauth_http: nil,
      upload_http: nil
    )
      raise Error, "YouTube client id missing" if client_id.blank?
      raise Error, "YouTube client secret missing" if client_secret.blank?
      raise Error, "YouTube refresh token missing" if refresh_token.blank?

      @client_id = client_id
      @client_secret = client_secret
      @refresh_token = refresh_token
      @oauth_http = oauth_http || Faraday.new(url: OAUTH_URL) do |f|
        f.request :url_encoded
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
      @upload_http = upload_http || Faraday.new do |f|
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    # Resumable upload via YouTube Data API v3 videos.insert.
    def publish_short(video_io:, title:, description:, recording_date:)
      token = access_token
      upload_location = initiate_resumable_upload(
        token: token,
        title: title,
        description: description,
        recording_date: recording_date
      )
      upload_video(upload_location, video_io, token)
    end

    private

    def access_token
      response = @oauth_http.post("/token") do |req|
        req.body = {
          grant_type: "refresh_token",
          client_id: @client_id,
          client_secret: @client_secret,
          refresh_token: @refresh_token
        }
      end
      payload = JSON.parse(response.body)
      token = payload["access_token"]
      raise Error, "YouTube access token missing: #{payload.inspect}" if token.blank?

      token
    rescue Faraday::Error => e
      raise Error, "YouTube token refresh failed: #{e.message}"
    end

    def initiate_resumable_upload(token:, title:, description:, recording_date:)
      metadata = AppConfig.youtube_upload_defaults.deep_merge(
        snippet: { title: title, description: description },
        recordingDetails: { recordingDate: recording_date.iso8601 }
      )

      response = @upload_http.post("#{UPLOAD_URL}/videos") do |req|
        req.params["uploadType"] = "resumable"
        req.params["part"] = "snippet,status,recordingDetails"
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Content-Type"] = "application/json; charset=UTF-8"
        req.body = metadata.to_json
      end
      location = response.headers["location"]
      raise Error, "YouTube resumable upload location missing" if location.blank?

      location
    rescue Faraday::Error => e
      raise Error, "YouTube upload initiation failed: #{e.message}"
    end

    def upload_video(upload_location, video_io, token)
      video_bytes = video_io.read
      response = @upload_http.put(upload_location) do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Content-Type"] = "video/mp4"
        req.headers["Content-Length"] = video_bytes.bytesize.to_s
        req.body = video_bytes
      end
      payload = JSON.parse(response.body)
      id = payload["id"]
      raise Error, "YouTube video id missing: #{payload.inspect}" if id.blank?

      id
    rescue Faraday::Error => e
      raise Error, "YouTube video upload failed: #{e.message}"
    end
  end
end
