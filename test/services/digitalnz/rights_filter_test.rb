require "test_helper"

module Digitalnz
  class RightsFilterTest < ActiveSupport::TestCase
    def reusable(overrides = {})
      {
        title: "Street scene",
        description: "Looking north",
        rights: [ "No known copyright restrictions" ],
        usage: [ "Modify", "Share", "Use commercially" ],
        content_partner: [ "Alexander Turnbull Library" ]
      }.merge(overrides)
    end

    test "accepts a reusable ATL photograph" do
      assert RightsFilter.acceptable?(reusable)
      assert RightsFilter.new(reusable).commercial_use?
    end

    test "allows councils museums public libraries and extras" do
      [
        "Wellington City Council Archives",
        "Canterbury Museum",
        "Auckland Libraries",
        "Feilding Library",
        "MOTAT",
        "Puke Ariki"
      ].each do |name|
        assert RightsFilter.allowed_partner?(name), "expected to allow #{name}"
      end
    end

    test "rejects partners that only look like libraries or museums" do
      [
        "The British Library",
        "Museums Victoria",
        "National Library of New Zealand",
        "John Kinder Theological Library",
        nil,
        ""
      ].each do |name|
        assert_not RightsFilter.allowed_partner?(name), "expected to reject #{name.inspect}"
      end
    end

    test "rejects disallowed content partners" do
      assert_not RightsFilter.acceptable?(reusable(content_partner: [ "iNaturalist NZ — Mātaki Taiao" ]))
    end

    test "rejects missing rights" do
      assert_not RightsFilter.acceptable?(reusable(rights: nil))
    end

    test "rejects records without Modify usage" do
      assert_not RightsFilter.acceptable?(reusable(rights: [ "All rights reserved" ], usage: %w[Share]))
    end

    test "rejects records without Use commercially usage" do
      record = reusable(usage: %w[Modify Share])
      assert_not RightsFilter.acceptable?(record)
      assert_not RightsFilter.new(record).commercial_use?
    end

    test "rejects colour keyword titles and tags" do
      assert_not RightsFilter.acceptable?(reusable(title: "Hand coloured postcard"))
      assert_not RightsFilter.acceptable?(reusable(subject: [ "coloured image" ]))
      assert_not RightsFilter.acceptable?(reusable(dc_type: [ "Transparency" ]))
      assert_not RightsFilter.acceptable?(reusable(dc_type: [ "Photograph slide" ]))
    end

    test "rejects non-photograph image types" do
      assert_not RightsFilter.acceptable?(reusable(dc_type: [ "Map" ]))
      assert_not RightsFilter.acceptable?(reusable(dc_type: [ "Poster" ]))
      assert_not RightsFilter.acceptable?(reusable(dc_type: [ "Specimen" ]))
    end

    test "accepts photograph negatives prints and lantern slides" do
      assert RightsFilter.acceptable?(reusable(dc_type: [ "Photograph - negative" ]))
      assert RightsFilter.acceptable?(reusable(
        content_partner: [ "Wellington City Council Archives" ],
        dc_type: [ "Photograph - print" ]
      ))
      assert RightsFilter.acceptable?(reusable(dc_type: [ "Lantern slides." ]))
    end

    test "rejects portrait and people-prominent tags" do
      assert_not RightsFilter.acceptable?(reusable(subject: [ "Portraits" ]))
      assert_not RightsFilter.acceptable?(reusable(subject: [ "people" ]))
      assert_not RightsFilter.acceptable?(reusable(subject: [ "Men" ]))
      assert_not RightsFilter.acceptable?(reusable(dc_type: [ "Portrait photographs." ]))
      assert_not RightsFilter.acceptable?(reusable(title: "Portrait of Mr James Coutt Crawford"))
    end

    test "does not treat clothing or description mentions as portraits" do
      assert RightsFilter.acceptable?(reusable(subject: [ "Womens clothing" ]))
      assert RightsFilter.acceptable?(reusable(subject: [ "Women photographers--New Zealand" ]))
      assert RightsFilter.acceptable?(reusable(description: "People on a street"))
    end
  end
end
