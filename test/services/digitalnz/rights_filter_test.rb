require "test_helper"

module Digitalnz
  class RightsFilterTest < ActiveSupport::TestCase
    test "accepts modifiable ATL-style records" do
      record = {
        title: "Street scene",
        description: "People on a street",
        rights: [ "No known copyright restrictions" ],
        usage: %w[Modify Share]
      }
      assert RightsFilter.acceptable?(record)
    end

    test "rejects missing rights" do
      record = { title: "Street scene", usage: %w[Modify] }
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

    test "rejects colour keyword titles" do
      record = {
        title: "Hand coloured postcard",
        rights: [ "No known copyright restrictions" ],
        usage: %w[Modify]
      }
      assert_not RightsFilter.acceptable?(record)
    end
  end
end
