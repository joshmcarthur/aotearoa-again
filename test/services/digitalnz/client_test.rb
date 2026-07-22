require "test_helper"

module Digitalnz
  class ClientTest < ActiveSupport::TestCase
    test "search works without an API key" do
      stub_request(:get, "https://api.digitalnz.org/v3/records.json")
        .with(query: hash_including("per_page" => "1"))
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
  end
end
