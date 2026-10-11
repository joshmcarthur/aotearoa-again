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

    test "allows partners from harvest config include globs" do
      assert RightsFilter.allowed_partner?("Wellington City Council Archives")
      assert RightsFilter.allowed_partner?("MOTAT")
      assert_not RightsFilter.allowed_partner?("iNaturalist NZ — Mātaki Taiao")
      assert_not RightsFilter.allowed_partner?(nil)
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
  end
end
