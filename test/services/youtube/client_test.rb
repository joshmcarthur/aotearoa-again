require "test_helper"

module Youtube
  class ClientTest < ActiveSupport::TestCase
    FakeResponse = Data.define(:body, :headers)

    class FakeOauthHttp
      attr_reader :posts

      def initialize(response_body:)
        @response_body = response_body
        @posts = []
      end

      def post(path, &block)
        @posts << { path: path }
        req = Request.new
        yield req if block
        FakeResponse.new(body: @response_body.to_json, headers: {})
      end

      class Request
        attr_accessor :body
      end
    end

    class FakeUploadHttp
      attr_reader :posts, :puts

      def initialize(post_headers:, put_response:)
        @post_headers = post_headers
        @put_response = put_response
        @posts = []
        @puts = []
      end

      def post(url, &block)
        req = Request.new
        yield req if block
        @posts << { url: url, params: req.params, body: req.body }
        FakeResponse.new(body: "", headers: @post_headers)
      end

      def put(url, &block)
        req = Request.new
        yield req if block
        @puts << { url: url, body: req.body }
        FakeResponse.new(body: @put_response.to_json, headers: {})
      end

      class Request
        attr_accessor :params, :headers, :body

        def initialize
          @params = {}
          @headers = {}
        end
      end
    end

    test "refreshes token and uploads short via resumable flow" do
      oauth = FakeOauthHttp.new(response_body: { "access_token" => "ya29.access" })
      upload = FakeUploadHttp.new(
        post_headers: { "location" => "https://upload.example/resumable/abc" },
        put_response: { "id" => "yt_video_42" }
      )
      client = Client.new(
        client_id: "client-id",
        client_secret: "client-secret",
        refresh_token: "refresh-token",
        oauth_http: oauth,
        upload_http: upload
      )
      recording_date = Time.zone.parse("2026-08-02 00:00:00")

      video_id = client.publish_short(
        video_io: StringIO.new("fake-mp4-bytes"),
        title: "Harbour scene #Shorts",
        description: "A colourised plate from ATL.",
        recording_date: recording_date
      )

      assert_equal "yt_video_42", video_id
      assert_equal 1, oauth.posts.size
      assert_equal "/token", oauth.posts.first[:path]

      assert_equal 1, upload.posts.size
      init = upload.posts.first
      assert_includes init[:url], "/upload/youtube/v3/videos"
      assert_equal "snippet,status,recordingDetails", init[:params]["part"]

      metadata = JSON.parse(init[:body])
      assert_equal "Harbour scene #Shorts", metadata.dig("snippet", "title")
      assert_equal "A colourised plate from ATL.", metadata.dig("snippet", "description")
      assert_equal "27", metadata.dig("snippet", "categoryId")
      assert_equal "public", metadata.dig("status", "privacyStatus")
      assert_equal false, metadata.dig("status", "selfDeclaredMadeForKids")
      assert_equal true, metadata.dig("status", "containsSyntheticMedia")
      assert_equal "New Zealand", metadata.dig("recordingDetails", "locationDescription")
      assert_equal recording_date.iso8601, metadata.dig("recordingDetails", "recordingDate")

      assert_equal 1, upload.puts.size
      assert_equal "https://upload.example/resumable/abc", upload.puts.first[:url]
    end

    test "raises when refresh token exchange fails" do
      oauth = Object.new
      def oauth.post(*)
        raise Faraday::ClientError, "invalid_grant"
      end

      client = Client.new(
        client_id: "client-id",
        client_secret: "client-secret",
        refresh_token: "refresh-token",
        oauth_http: oauth,
        upload_http: Object.new
      )

      error = assert_raises(Client::Error) do
        client.publish_short(
          video_io: StringIO.new("x"),
          title: "x",
          description: "x",
          recording_date: Time.zone.now
        )
      end
      assert_match(/token refresh failed/, error.message)
    end

    test "raises when resumable upload location missing" do
      oauth = FakeOauthHttp.new(response_body: { "access_token" => "ya29.access" })
      upload = FakeUploadHttp.new(post_headers: {}, put_response: {})

      client = Client.new(
        client_id: "client-id",
        client_secret: "client-secret",
        refresh_token: "refresh-token",
        oauth_http: oauth,
        upload_http: upload
      )

      error = assert_raises(Client::Error) do
        client.publish_short(
          video_io: StringIO.new("x"),
          title: "x",
          description: "x",
          recording_date: Time.zone.now
        )
      end
      assert_match(/upload location missing/, error.message)
    end

    test "raises when credentials missing" do
      error = assert_raises(Client::Error) do
        Client.new(client_id: nil, client_secret: "x", refresh_token: "x")
      end
      assert_match(/client id missing/, error.message)
    end
  end
end
