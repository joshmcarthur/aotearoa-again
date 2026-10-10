require "test_helper"

module Digitalnz
  class RandomSelectorTest < ActiveSupport::TestCase
    class FakeClient
      WHARF = {
        "id" => 99,
        "title" => "Wharf",
        "rights" => [ "No known copyright restrictions" ],
        "usage" => [ "Modify", "Share", "Use commercially" ],
        "content_partner" => [ "Alexander Turnbull Library" ],
        "dc_type" => [ "Photograph - print" ],
        "subject" => [ "Harbours" ]
      }.freeze

      def search(params)
        if params[:facets] == "content_partner" || params["facets"] == "content_partner"
          {
            "search" => {
              "facets" => {
                "content_partner" => {
                  "iNaturalist NZ — Mātaki Taiao" => 1_000,
                  "Alexander Turnbull Library" => 10
                }
              }
            }
          }
        elsif params[:facets] == "decade" || params["facets"] == "decade"
          {
            "search" => {
              "facets" => {
                "decade" => { "1910" => 10 }
              },
              "result_count" => 0
            }
          }
        else
          {
            "search" => {
              "result_count" => 1,
              "results" => [ WHARF ]
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
        usage_flags: [ "Modify", "Use commercially" ]
      )

      selector = RandomSelector.new(client: FakeClient.new, exclude_ids: SourceItem.pluck(:digitalnz_id))
      assert_nil selector.call
    end

    test "selects record when not excluded" do
      selector = RandomSelector.new(client: FakeClient.new, exclude_ids: [])
      record = selector.call
      assert_equal 99, record["id"]
    end

    test "searches a sampled allowed partner rather than aggregators" do
      searches = []
      client = Object.new
      client.define_singleton_method(:search) do |params|
        searches << params
        if params[:facets] == "content_partner" || params["facets"] == "content_partner"
          {
            "search" => {
              "facets" => {
                "content_partner" => {
                  "iNaturalist NZ — Mātaki Taiao" => 9_000,
                  "Wellington City Council Archives" => 20
                }
              }
            }
          }
        elsif params[:facets] == "decade" || params["facets"] == "decade"
          { "search" => { "facets" => { "decade" => { "1920" => 20 } } } }
        else
          {
            "search" => {
              "result_count" => 1,
              "results" => [
                {
                  "id" => 77,
                  "title" => "Lambton Quay",
                  "rights" => [ "No known copyright restrictions" ],
                  "usage" => [ "Modify", "Share", "Use commercially" ],
                  "content_partner" => [ "Wellington City Council Archives" ],
                  "dc_type" => [ "Photograph - negative" ],
                  "subject" => [ "Streets" ]
                }
              ]
            }
          }
        end
      end

      record = RandomSelector.new(client: client, exclude_ids: []).call

      assert_equal 77, record["id"]
      partner_queries = searches.select { |params| params["and[content_partner][]"] }
      assert partner_queries.any?
      assert partner_queries.all? { |params| params["and[content_partner][]"] == "Wellington City Council Archives" }
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
      pages = 50.times.map { selector.send(:pick_page, "Alexander Turnbull Library", "1980") }
      assert pages.all? { |page| page.between?(1, 100) }
      assert pages.max <= RandomSelector::ANONYMOUS_MAX_PAGE
    end
  end
end
