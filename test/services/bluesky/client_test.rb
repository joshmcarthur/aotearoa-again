require "test_helper"

module Bluesky
  class ClientTest < ActiveSupport::TestCase
    FakeResponse = Data.define(:body)

    class FakeHttp
      attr_reader :requests

      def initialize
        @requests = []
        @create_record_count = 0
      end

      def post(url)
        @requests << { url: url, headers: {}, body: nil }
        req = RequestBuilder.new(@requests.last)
        yield req if block_given?

        if url.include?("createSession")
          FakeResponse.new(body: { did: "did:plc:test", accessJwt: "jwt-token" }.to_json)
        elsif url.include?("uploadBlob")
          FakeResponse.new(body: {
            blob: {
              "$type" => "blob",
              "ref" => { "$link" => "bafythumb" },
              "mimeType" => req.headers["Content-Type"],
              "size" => req.body.bytesize
            }
          }.to_json)
        elsif url.include?("createRecord")
          @create_record_count += 1
          collection = JSON.parse(req.body).fetch("collection")
          FakeResponse.new(body: {
            uri: "at://did:plc:test/#{collection}/record#{@create_record_count}",
            cid: "bafyrecord#{@create_record_count}"
          }.to_json)
        else
          raise "unexpected url #{url}"
        end
      end

      class RequestBuilder
        def initialize(request)
          @request = request
        end

        def headers
          @request[:headers]
        end

        def body=(value)
          @request[:body] = value
        end

        def body
          @request[:body]
        end
      end
    end

    setup do
      @http = FakeHttp.new
      @client = Client.new(handle: "aotearoa.test", app_password: "pass-word", http: @http)
    end

    test "upload_blob authenticates and posts bytes" do
      blob = @client.upload_blob("image-bytes", content_type: "image/jpeg")

      assert_equal "bafythumb", blob.dig("ref", "$link")
      assert_equal 1, @http.requests.count { |r| r[:url].include?("createSession") }
      assert_equal "Bearer jwt-token", @http.requests.find { |r| r[:url].include?("uploadBlob") }[:headers]["Authorization"]
    end

    test "publish_edition_post includes associatedRefs on external embed" do
      thumb = {
        "$type" => "blob",
        "ref" => { "$link" => "bafythumb" },
        "mimeType" => "image/jpeg",
        "size" => 10
      }

      ref = @client.publish_edition_post(
        text: "Harbour scene\n\nhttps://example.com/editions/2026-07-25",
        uri: "https://example.com/editions/2026-07-25",
        title: "Harbour scene",
        description: "A harbour view",
        thumb_blob: thumb,
        document_ref: { uri: "at://did:plc:test/site.standard.document/doc1", cid: "bafydoc" },
        publication_ref: { uri: "at://did:plc:test/site.standard.publication/pub1", cid: "bafypub" }
      )

      assert_equal "at://did:plc:test/app.bsky.feed.post/record1", ref[:uri]
      post_request = @http.requests.find { |r| r[:url].include?("createRecord") }
      payload = JSON.parse(post_request[:body])
      embed = payload.dig("record", "embed", "external")
      assert_equal 2, embed.fetch("associatedRefs").size
      assert_equal "at://did:plc:test/site.standard.document/doc1", embed.fetch("associatedRefs").first.fetch("uri")
    end
  end
end
