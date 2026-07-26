require "test_helper"

module Digitalnz
  class RandomSelectorTest < ActiveSupport::TestCase
    class FakeClient
      def search(params)
        if params[:facets] == "decade" || params["facets"] == "decade"
          {
            "search" => {
              "facets" => {
                "decade" => { "1910" => 10 }
              },
              "result_count" => 0
            }
          }
        elsif params["and[decade][]"] == "1910" && params[:page].to_i <= 1
          {
            "search" => {
              "result_count" => 1,
              "results" => [
                {
                  "id" => 99,
                  "title" => "Wharf",
                  "rights" => [ "No known copyright restrictions" ],
                  "usage" => [ "Modify", "Share", "Use commercially" ]
                }
              ]
            }
          }
        else
          {
            "search" => {
              "result_count" => 1,
              "results" => [
                {
                  "id" => 99,
                  "title" => "Wharf",
                  "rights" => [ "No known copyright restrictions" ],
                  "usage" => [ "Modify", "Share", "Use commercially" ]
                }
              ]
            }
          }
        end
      end
    end

    test "returns a new acceptable record and excludes known ids" do
      SourceItem.create!(
        digitalnz_id: "99",
        title: "Existing",
        record_url: "https://example.com",
        dedupe_key: "digitalnz:99",
        rights_text: "x",
        usage_flags: [ "Modify", "Use commercially" ],
        meta_upload_eligible: true
      )

      selector = RandomSelector.new(client: FakeClient.new, exclude_ids: SourceItem.pluck(:digitalnz_id))
      assert_nil selector.call
    end

    test "selects record when not excluded" do
      selector = RandomSelector.new(client: FakeClient.new, exclude_ids: [])
      record = selector.call
      assert_equal 99, record["id"]
    end

    test "caps anonymous pagination at page 100" do
      client = Object.new
      def client.search(params)
        if params[:facets] == "decade" || params["facets"] == "decade"
          { "search" => { "facets" => { "decade" => { "1980" => 10_000 } } } }
        else
          { "search" => { "result_count" => 10_000, "results" => [] } }
        end
      end

      selector = RandomSelector.new(client: client, exclude_ids: [], authenticated: false)
      pages = 50.times.map { selector.send(:pick_page, "1980") }
      assert pages.all? { |page| page.between?(1, 100) }
      assert pages.max <= RandomSelector::ANONYMOUS_MAX_PAGE
    end
  end
end
