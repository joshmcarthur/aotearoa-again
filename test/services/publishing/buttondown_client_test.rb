require "test_helper"

module Publishing
  class ButtondownClientTest < ActiveSupport::TestCase
    setup do
      @api_key = "test-buttondown-key"
      @client = ButtondownClient.new(api_key: @api_key)
    end

    test "creates a draft then publishes immediately" do
      create_stub = stub_request(:post, "https://api.buttondown.com/v1/emails")
        .with(
          headers: { "Authorization" => "Token #{@api_key}" },
          body: hash_including(
            "subject" => "Harbour scene",
            "body" => "Hello",
            "status" => "draft",
            "canonical_url" => "https://example.com/editions/2026-07-26"
          )
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { id: "bd_456", status: "draft" }.to_json
        )

      publish_stub = stub_request(:post, "https://api.buttondown.com/v1/emails/bd_456/publish")
        .with(
          headers: { "Authorization" => "Token #{@api_key}" },
          body: {}
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { id: "bd_456", status: "about_to_send" }.to_json
        )

      payload = @client.create_and_send(
        subject: "Harbour scene",
        body: "Hello",
        canonical_url: "https://example.com/editions/2026-07-26"
      )

      assert_equal "bd_456", payload["id"]
      assert_requested(create_stub)
      assert_requested(publish_stub)
    end

    test "raises Error when create fails" do
      stub_request(:post, "https://api.buttondown.com/v1/emails")
        .to_return(status: 401, body: "unauthorized")

      error = assert_raises(ButtondownClient::Error) do
        @client.create_and_send(subject: "Harbour scene", body: "Hello")
      end
      assert_match(/Buttondown request failed/, error.message)
      assert_not_requested(:post, "https://api.buttondown.com/v1/emails/bd_456/publish")
    end

    test "raises Error when publish fails" do
      stub_request(:post, "https://api.buttondown.com/v1/emails")
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { id: "bd_789", status: "draft" }.to_json
        )
      stub_request(:post, "https://api.buttondown.com/v1/emails/bd_789/publish")
        .to_return(status: 500, body: "boom")

      error = assert_raises(ButtondownClient::Error) do
        @client.create_and_send(subject: "Harbour scene", body: "Hello")
      end
      assert_match(/Buttondown request failed/, error.message)
    end
  end
end
