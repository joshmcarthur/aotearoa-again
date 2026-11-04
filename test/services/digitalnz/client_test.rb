require "test_helper"

module Digitalnz
  class ClientTest < ActiveSupport::TestCase
    test "search works without an API key" do
      stub_request(:get, "https://api.digitalnz.org/v3/records.json")
        .with(query: hash_including("per_page" => "1"), headers: { "User-Agent" => Client::USER_AGENT })
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            search: {
              result_count: 1,
              results: [ { id: 12345, title: "Fixture photograph" } ]
            }
          }.to_json
        )

      data = Client.new(api_key: nil).search(per_page: 1, page: 1)

      assert_equal 1, data.dig("search", "result_count")
      assert_equal "Fixture photograph", data.dig("search", "results", 0, "title")
      assert_not_requested(:get, %r{api_key=})
    end

    test "sends optional key in Authentication-Token header" do
      stub_request(:get, "https://api.digitalnz.org/v3/records.json")
        .with(
          query: hash_including("per_page" => "1"),
          headers: { "Authentication-Token" => "secret-token" }
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { search: { result_count: 0, results: [] } }.to_json
        )

      Client.new(api_key: "secret-token").search(per_page: 1)
      assert_requested(
        :get,
        "https://api.digitalnz.org/v3/records.json",
        headers: { "Authentication-Token" => "secret-token" },
        query: hash_including("per_page" => "1")
      )
    end

    test "retries the same request after a 403" do
      stub_request(:get, "https://api.digitalnz.org/v3/records.json")
        .with(query: hash_including("per_page" => "1"), headers: { "User-Agent" => Client::USER_AGENT })
        .to_return(
          { status: 403, body: "blocked" },
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { search: { result_count: 1, results: [] } }.to_json
          }
        )

      waits = []
      data = Client.new(api_key: nil, sleeper: ->(seconds) { waits << seconds }).search(per_page: 1)

      assert_equal 1, data.dig("search", "result_count")
      assert_equal [ Client::RATE_LIMIT_WAIT ], waits
    end

    test "raises when a 403 persists" do
      stub_request(:get, "https://api.digitalnz.org/v3/records.json")
        .with(query: hash_including("per_page" => "1"))
        .to_return(status: 403, body: "blocked")

      waits = []
      error = assert_raises(Client::RateLimited) do
        Client.new(api_key: nil, sleeper: ->(seconds) { waits << seconds }).search(per_page: 1)
      end

      assert_equal [ Client::RATE_LIMIT_WAIT ] * Client::MAX_RATE_LIMIT_RETRIES, waits
      assert_match(/DigitalNZ request failed/, error.message)
    end

    test "does not wait on a server error" do
      stub_request(:get, "https://api.digitalnz.org/v3/records.json")
        .with(query: hash_including("per_page" => "1"))
        .to_return(status: 500, body: "down")

      waits = []
      assert_raises(Client::Error) do
        Client.new(api_key: nil, sleeper: ->(seconds) { waits << seconds }).search(per_page: 1)
      end
      assert_empty waits
    end
  end
end
