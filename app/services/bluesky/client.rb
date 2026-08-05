require "faraday"
require "json"

module Bluesky
  class Client
    class Error < StandardError; end

    def initialize(
      handle: AppConfig.bluesky_handle,
      app_password: AppConfig.bluesky_app_password,
      pds_host: AppConfig.bluesky_pds_host,
      http: nil
    )
      raise Error, "Bluesky handle missing" if handle.blank?
      raise Error, "Bluesky app password missing" if app_password.blank?

      @handle = handle
      @app_password = app_password
      @pds_host = pds_host.presence || "bsky.social"
      @http = http
      @session = nil
    end

    def upload_blob(bytes, content_type:)
      response = authed_post(
        "/xrpc/com.atproto.repo.uploadBlob",
        body: bytes,
        content_type: content_type
      )
      blob = JSON.parse(response.body)["blob"]
      raise Error, "uploadBlob missing blob ref" if blob.blank?

      blob
    rescue Faraday::Error => e
      raise Error, "Bluesky blob upload failed: #{e.message}"
    end

    def create_record(collection:, record:)
      payload = {
        repo: session.fetch("did"),
        collection: collection,
        record: record
      }
      response = authed_post(
        "/xrpc/com.atproto.repo.createRecord",
        body: payload.to_json,
        content_type: "application/json"
      )
      body = JSON.parse(response.body)
      uri = body["uri"].presence
      cid = body["cid"].presence
      raise Error, "createRecord missing uri/cid: #{body.inspect}" if uri.blank? || cid.blank?

      { uri: uri, cid: cid }
    rescue Faraday::Error => e
      raise Error, "Bluesky createRecord failed: #{e.message}"
    end

    def publish_edition_post(text:, uri:, title:, description:, thumb_blob:, document_ref:, publication_ref:)
      record = {
        "$type" => "app.bsky.feed.post",
        "text" => text,
        "createdAt" => Time.current.utc.iso8601(3),
        "langs" => [ "en" ],
        "embed" => {
          "$type" => "app.bsky.embed.external",
          "external" => {
            "uri" => uri,
            "title" => title,
            "description" => description,
            "thumb" => thumb_blob,
            "associatedRefs" => [
              { "uri" => document_ref.fetch(:uri), "cid" => document_ref.fetch(:cid) },
              { "uri" => publication_ref.fetch(:uri), "cid" => publication_ref.fetch(:cid) }
            ]
          }
        }
      }

      create_record(collection: "app.bsky.feed.post", record: record)
    end

    private

    def session
      @session ||= authenticate
    end

    def authenticate
      response = pds_post(
        "/xrpc/com.atproto.server.createSession",
        body: { identifier: @handle, password: @app_password }.to_json,
        content_type: "application/json"
      )
      body = JSON.parse(response.body)
      raise Error, "Bluesky session missing did" if body["did"].blank?
      raise Error, "Bluesky session missing accessJwt" if body["accessJwt"].blank?

      body
    rescue Faraday::Error => e
      raise Error, "Bluesky authentication failed: #{e.message}"
    end

    def authed_post(path, body:, content_type:)
      pds_post(path, body: body, content_type: content_type, access_jwt: session.fetch("accessJwt"))
    end

    def pds_post(path, body:, content_type:, access_jwt: nil)
      http.post("#{pds_base_url}#{path}") do |req|
        req.headers["Content-Type"] = content_type
        req.headers["Authorization"] = "Bearer #{access_jwt}" if access_jwt.present?
        req.body = body
      end
    end

    def http
      @http ||= Faraday.new do |f|
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def pds_base_url
      "https://#{@pds_host}"
    end
  end
end
