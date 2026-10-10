require "test_helper"

module Digitalnz
  class RecordFilterTest < ActiveSupport::TestCase
    def reusable(overrides = {})
      {
        title: "Queen Street",
        description: "Looking north",
        rights: [ "No known copyright restrictions" ],
        usage: [ "Modify", "Share", "Use commercially" ],
        content_partner: [ "Alexander Turnbull Library" ],
        dc_type: [],
        subject: []
      }.merge(overrides)
    end

    test "accepts a reusable ATL street photograph" do
      assert RecordFilter.acceptable?(reusable)
    end

    test "rejects disallowed content partners" do
      assert_not RecordFilter.acceptable?(reusable(content_partner: [ "iNaturalist NZ — Mātaki Taiao" ]))
    end

    test "rejects colour keyword titles" do
      assert_not RecordFilter.acceptable?(reusable(title: "Hand coloured postcard"))
    end

    test "rejects colour tags on subject or type" do
      assert_not RecordFilter.acceptable?(reusable(subject: [ "coloured image" ]))
      assert_not RecordFilter.acceptable?(reusable(dc_type: [ "Transparency" ]))
      assert_not RecordFilter.acceptable?(reusable(dc_type: [ "Photograph slide" ]))
    end

    test "rejects non-photograph image types" do
      assert_not RecordFilter.acceptable?(reusable(dc_type: [ "Map" ]))
      assert_not RecordFilter.acceptable?(reusable(dc_type: [ "Poster" ]))
      assert_not RecordFilter.acceptable?(reusable(dc_type: [ "Art work" ]))
      assert_not RecordFilter.acceptable?(reusable(dc_type: [ "Specimen" ]))
    end

    test "accepts photograph negatives, prints, and lantern slides" do
      assert RecordFilter.acceptable?(reusable(dc_type: [ "Photograph - negative" ]))
      assert RecordFilter.acceptable?(reusable(
        content_partner: [ "Wellington City Council Archives" ],
        dc_type: [ "Photograph - print" ]
      ))
      assert RecordFilter.acceptable?(reusable(dc_type: [ "Lantern slides." ]))
    end

    test "rejects portrait and people-prominent DigitalNZ tags" do
      assert_not RecordFilter.acceptable?(reusable(subject: [ "Portraits" ]))
      assert_not RecordFilter.acceptable?(reusable(subject: [ "studio portraits" ]))
      assert_not RecordFilter.acceptable?(reusable(subject: [ "Group portraits" ]))
      assert_not RecordFilter.acceptable?(reusable(subject: [ "people" ]))
      assert_not RecordFilter.acceptable?(reusable(subject: [ "Men" ]))
      assert_not RecordFilter.acceptable?(reusable(dc_type: [ "Portrait photographs." ]))
    end

    test "rejects portrait titles even without tags" do
      assert_not RecordFilter.acceptable?(reusable(title: "Portrait of Mr James Coutt Crawford"))
    end

    test "does not treat clothing or photographer subjects as portraits" do
      assert RecordFilter.acceptable?(reusable(subject: [ "Womens clothing" ]))
      assert RecordFilter.acceptable?(reusable(subject: [ "Women photographers--New Zealand" ]))
    end

    test "does not reject a street scene that only mentions people in the description" do
      assert RecordFilter.acceptable?(reusable(description: "People on a street"))
    end
  end
end
