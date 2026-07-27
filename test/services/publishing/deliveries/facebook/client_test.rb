require "test_helper"

module Publishing
  module Deliveries
    class Facebook
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

        test "publishes page photo in one step" do
          http = FakeHttp.new([ { "id" => "photo_1", "post_id" => "page_post_2" } ])
          client = Client.new(
            access_token: "token",
            page_id: "page_99",
            http: http
          )

          post_id = client.publish_photo(
            image_url: "https://example.com/editions/2026-07-25/share.jpg",
            caption: "Harbour scene\n\nhttps://example.com/editions/2026-07-25"
          )

          assert_equal "photo_1", post_id
          assert_equal 1, http.posts.size
          assert_equal "page_99/photos", http.posts[0][:path]
          assert_equal "https://example.com/editions/2026-07-25/share.jpg", http.posts[0][:params][:url]
          assert_includes http.posts[0][:params][:caption], "Harbour scene"
          assert_equal "token", http.posts[0][:params][:access_token]
        end

        test "raises when photo publish fails" do
          http = Object.new
          def http.post(*)
            raise Faraday::ClientError, "bad request"
          end

          client = Client.new(access_token: "token", page_id: "page_99", http: http)
          error = assert_raises(Client::Error) do
            client.publish_photo(image_url: "https://example.com/x.jpg", caption: "x")
          end
          assert_match(/Facebook photo publish failed/, error.message)
        end

        test "raises when page id missing" do
          client = Client.new(access_token: "token", page_id: nil)
          error = assert_raises(Client::Error) do
            client.publish_photo(image_url: "https://example.com/x.jpg", caption: "x")
          end
          assert_match(/Facebook not configured/, error.message)
        end
      end
    end
  end
end
