require "test_helper"

module Digitalnz
  class HarvesterTest < ActiveSupport::TestCase
    class FakeSelector
      def initialize(records)
        @records = records
      end

      def call
        @records.shift
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

    def reusable_record
      {
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
    end

    test "creates a candidate for a greyscale photograph" do
      body = File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg"))
      harvester = Harvester.new(
        selector: FakeSelector.new([ reusable_record ]),
        downloader: FakeDownloader.new(body)
      )

      candidate = harvester.call

      assert_not_nil candidate
      assert candidate.original_image.attached?
      assert_equal "Auckland Libraries", candidate.source_item.content_partner
    end

    test "skips colour downloads without persisting a source item" do
      red = Vips::Image.black(16, 16, bands: 3).new_from_image([ 220, 20, 20 ]).copy(interpretation: :srgb)
      harvester = Harvester.new(
        selector: FakeSelector.new([ reusable_record ]),
        downloader: FakeDownloader.new(red.jpegsave_buffer(Q: 90))
      )

      assert_nil harvester.call
      assert_equal 0, SourceItem.where(digitalnz_id: "harvest-1").count
    end
  end
end
