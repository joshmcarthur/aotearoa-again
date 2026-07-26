require "test_helper"

module Digitalnz
  class RightsFilterTest < ActiveSupport::TestCase
    test "accepts modifiable commercially reusable ATL-style records" do
      record = {
        title: "Street scene",
        description: "People on a street",
        rights: [ "No known copyright restrictions" ],
        usage: [ "Modify", "Share", "Use commercially" ]
      }
      assert RightsFilter.acceptable?(record)
      assert RightsFilter.new(record).meta_upload_eligible?
    end

    test "rejects missing rights" do
      record = { title: "Street scene", usage: [ "Modify", "Use commercially" ] }
      assert_not RightsFilter.acceptable?(record)
    end

    test "rejects records without Modify usage" do
      record = {
        title: "Street scene",
        rights: [ "All rights reserved" ],
        usage: %w[Share]
      }
      assert_not RightsFilter.acceptable?(record)
    end

    test "rejects records without Use commercially usage" do
      record = {
        title: "Street scene",
        rights: [ "No known copyright restrictions" ],
        usage: %w[Modify Share]
      }
      assert_not RightsFilter.acceptable?(record)
      assert_not RightsFilter.new(record).meta_upload_eligible?
    end

    test "rejects colour keyword titles" do
      record = {
        title: "Hand coloured postcard",
        rights: [ "No known copyright restrictions" ],
        usage: [ "Modify", "Use commercially" ]
      }
      assert_not RightsFilter.acceptable?(record)
    end
  end
end
