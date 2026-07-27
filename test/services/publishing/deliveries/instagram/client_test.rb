require "test_helper"

module Publishing
  module Deliveries
    class Instagram
      class ClientTest < ActiveSupport::TestCase
        FakeResponse = Data.define(:body)

        class FakeHttp
          attr_reader :posts

          def initialize(responses)
            @responses = responses
            @posts = []
          end

          def post(path, params = {})
            @posts << { path: path, params: params }
            body = @responses.shift
            raise Faraday::Error, "unexpected request #{path}" if body.nil?

            FakeResponse.new(body: body.to_json)
          end
        end

        test "creates media container then publishes" do
          http = FakeHttp.new([
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
  end
end
