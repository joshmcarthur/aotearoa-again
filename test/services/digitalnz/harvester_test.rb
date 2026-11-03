require "test_helper"

module Digitalnz
  class HarvesterTest < ActiveSupport::TestCase
    class FakeSelector
      def initialize(record)
        @record = record
      end

      def call
        @record
      end
    end

    class FakeDownloader
      def initialize(body)
        @body = body
      end

      def call(_url)
        {
          io: StringIO.new(@body),
          filename: "original.jpg",
          content_type: "image/jpeg"
        }
      end
    end

    test "creates a candidate from the selected record" do
      record = {
        "id" => "harvest-1",
        "title" => "Queen Street",
        "description" => [ "Looking north" ],
        "rights" => [ "No known copyright restrictions" ],
        "usage" => [ "Modify", "Share", "Use commercially" ],
        "content_partner" => [ "Auckland Libraries" ],
        "landing_url" => "https://digitalnz.org/records/harvest-1",
        "large_thumbnail_url" => [ "https://example.com/large.jpg" ],
        "dc_type" => [ "Photograph - print" ],
        "subject" => [ "Streets" ]
      }
      body = File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg"))
      harvester = Harvester.new(
        selector: FakeSelector.new(record),
        downloader: FakeDownloader.new(body)
      )

      candidate = harvester.call

      assert_not_nil candidate
      assert candidate.original_image.attached?
      assert_equal "Auckland Libraries", candidate.source_item.content_partner
    end
  end
end
