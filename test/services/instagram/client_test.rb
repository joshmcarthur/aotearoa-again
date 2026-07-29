require "test_helper"

module Instagram
  class ClientTest < ActiveSupport::TestCase
        FakeResponse = Data.define(:body)

        class FakeHttp
          attr_reader :posts, :gets

          def initialize(post_responses:, get_responses: [])
            @post_responses = post_responses
            @get_responses = get_responses
            @posts = []
            @gets = []
          end

          def post(path, params = {})
            @posts << { path: path, params: params }
            body = @post_responses.shift
            raise Faraday::Error, "unexpected request #{path}" if body.nil?

            FakeResponse.new(body: body.to_json)
          end

          def get(path, params = {})
            @gets << { path: path, params: params }
            body = @get_responses.shift
            raise Faraday::Error, "unexpected get #{path}" if body.nil?

            FakeResponse.new(body: body.to_json)
          end
        end

        test "creates media container then publishes" do
          http = FakeHttp.new(post_responses: [
            { "id" => "container_1" },
            { "id" => "media_9" }
          ])
          client = Client.new(
            access_token: "token",
            instagram_user_id: "ig_user",
            http: http
          )

          media_id = client.publish_photo(
            image_url: "https://example.com/editions/2026-07-25/share.jpg",
            caption: "Harbour scene",
            alt_text: "Harbour scene. A photograph of the waterfront."
          )

          assert_equal "media_9", media_id
          assert_equal 2, http.posts.size
          assert_equal "ig_user/media", http.posts[0][:path]
          assert_equal "https://example.com/editions/2026-07-25/share.jpg", http.posts[0][:params][:image_url]
          assert_equal "Harbour scene", http.posts[0][:params][:caption]
          assert_equal "token", http.posts[0][:params][:access_token]
          assert_equal "ig_user/media_publish", http.posts[1][:path]
          assert_equal "container_1", http.posts[1][:params][:creation_id]
        end

        test "publishes reel after polling finished" do
          sleeps = []
          clock_values = [ 0.0, 1.0, 2.0 ]
          http = FakeHttp.new(
            post_responses: [
              { "id" => "reel_container" },
              { "id" => "reel_media" }
            ],
            get_responses: [
              { "status_code" => "IN_PROGRESS", "id" => "reel_container" },
              { "status_code" => "FINISHED", "id" => "reel_container" }
            ]
          )
          client = Client.new(
            access_token: "token",
            instagram_user_id: "ig_user",
            http: http,
            sleeper: ->(seconds) { sleeps << seconds },
            clock: -> { clock_values.shift || 2.0 }
          )

          media_id = client.publish_reel(
            video_url: "https://example.com/editions/2026-07-25/share.mp4",
            caption: "Harbour scene",
            cover_url: "https://example.com/editions/2026-07-25/share.jpg",
            share_to_feed: false
          )

          assert_equal "reel_media", media_id
          assert_equal "REELS", http.posts[0][:params][:media_type]
          assert_equal "https://example.com/editions/2026-07-25/share.mp4", http.posts[0][:params][:video_url]
          assert_equal "https://example.com/editions/2026-07-25/share.jpg", http.posts[0][:params][:cover_url]
          assert_equal "false", http.posts[0][:params][:share_to_feed]
          assert_equal 2, http.gets.size
          assert_equal [ Client::REEL_POLL_INTERVAL_S ], sleeps
          assert_equal "ig_user/media_publish", http.posts[1][:path]
          assert_equal "reel_container", http.posts[1][:params][:creation_id]
        end

        test "raises when reel processing errors" do
          http = FakeHttp.new(
            post_responses: [ { "id" => "reel_container" } ],
            get_responses: [ { "status_code" => "ERROR", "id" => "reel_container" } ]
          )
          client = Client.new(
            access_token: "token",
            instagram_user_id: "ig_user",
            http: http,
            sleeper: ->(_) { },
            clock: -> { 0.0 }
          )

          error = assert_raises(Client::Error) do
            client.publish_reel(video_url: "https://example.com/x.mp4", caption: "x")
          end
          assert_match(/processing failed/, error.message)
        end

        test "raises when reel processing times out" do
          http = FakeHttp.new(
            post_responses: [ { "id" => "reel_container" } ],
            get_responses: [ { "status_code" => "IN_PROGRESS", "id" => "reel_container" } ]
          )
          clock_values = [ 0.0, Client::REEL_POLL_TIMEOUT_S ]
          client = Client.new(
            access_token: "token",
            instagram_user_id: "ig_user",
            http: http,
            sleeper: ->(_) { },
            clock: -> { clock_values.shift || Client::REEL_POLL_TIMEOUT_S }
          )

          error = assert_raises(Client::Error) do
            client.publish_reel(video_url: "https://example.com/x.mp4", caption: "x")
          end
          assert_match(/timed out/, error.message)
        end

        test "raises when container create fails" do
          http = Object.new
          def http.post(*)
            raise Faraday::ClientError, "bad request"
          end

          client = Client.new(access_token: "token", instagram_user_id: "ig_user", http: http)
          error = assert_raises(Client::Error) do
            client.publish_photo(image_url: "https://example.com/x.jpg", caption: "x")
          end
          assert_match(/media create failed/, error.message)
        end

        test "raises when instagram user id missing" do
          client = Client.new(access_token: "token", instagram_user_id: nil)
          error = assert_raises(Client::Error) do
            client.publish_photo(image_url: "https://example.com/x.jpg", caption: "x")
          end
          assert_match(/Instagram not configured/, error.message)
        end
  end
end
