require "test_helper"

module Digitalnz
  class MetaEligibilityTest < ActiveSupport::TestCase
    test "eligible when Use commercially present" do
      record = {
        rights: [ "No known copyright restrictions" ],
        usage: [ "Modify", "Use commercially" ]
      }
      assert MetaEligibility.eligible?(record)
    end

    test "ineligible without Use commercially" do
      record = {
        rights: [ "No known copyright restrictions" ],
        usage: %w[Modify Share]
      }
      assert_not MetaEligibility.eligible?(record)
    end
  end
end
