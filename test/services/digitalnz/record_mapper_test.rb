require "test_helper"

module Digitalnz
  class RecordMapperTest < ActiveSupport::TestCase
    test "maps digitalnz record into source attributes" do
      record = {
        "id" => 42,
        "title" => "Queen Street",
        "description" => [ "Looking north" ],
        "display_date" => "1912",
        "year" => [ "1912" ],
        "placename" => [ "Auckland" ],
        "creator" => [ "Photographer" ],
        "content_partner" => [ "Alexander Turnbull Library" ],
        "rights" => [ "No known copyright restrictions" ],
        "usage" => [ "Modify", "Share", "Use commercially" ],
        "landing_url" => "https://natlib.govt.nz/records/123",
        "large_thumbnail_url" => [ "https://example.com/large.jpg" ]
      }

      attrs = RecordMapper.to_source_attributes(record)
      assert_equal "42", attrs[:digitalnz_id]
      assert_equal "Queen Street", attrs[:title]
      assert_equal "Looking north", attrs[:description]
      assert_equal 1912, attrs[:year]
      assert_equal "Auckland", attrs[:placename]
      assert_equal "digitalnz:42", attrs[:dedupe_key]
      assert_equal "https://example.com/large.jpg", attrs[:image_url]
      assert_includes attrs[:usage_flags], "Modify"
      assert_includes attrs[:usage_flags], "Use commercially"
    end
  end
end
