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
      def initialize(body: nil, error: nil)
        @body = body
        @error = error
        @calls = 0
      end

      attr_reader :calls

      def call(_url)
        @calls += 1
        raise @error if @error

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

    test "creates a candidate from the selected record" do
      body = File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg"))
      harvester = Harvester.new(
        selector: FakeSelector.new([ reusable_record ]),
        downloader: FakeDownloader.new(body: body)
      )

      candidate = harvester.call

      assert_not_nil candidate
      assert candidate.original_image.attached?
      assert_equal "Auckland Libraries", candidate.source_item.content_partner
    end

    test "persists a downloaded image even when it is colour" do
      red = Vips::Image.black(16, 16, bands: 3).new_from_image([ 220, 20, 20 ]).copy(interpretation: :srgb)
      harvester = Harvester.new(
        selector: FakeSelector.new([ reusable_record ]),
        downloader: FakeDownloader.new(body: red.jpegsave_buffer(Q: 90))
      )

      candidate = harvester.call

      assert_not_nil candidate
      assert_equal "harvest-1", candidate.source_item.digitalnz_id
    end

    test "does not retry when download fails" do
      downloader = FakeDownloader.new(error: ImageDownloader::Error.new("boom"))
      harvester = Harvester.new(
        selector: FakeSelector.new([ reusable_record, reusable_record.merge("id" => "harvest-2") ]),
        downloader: downloader
      )

      error = assert_raises(ImageDownloader::Error) { harvester.call }
      assert_equal "boom", error.message
      assert_equal 1, downloader.calls
      assert_nil SourceItem.find_by(digitalnz_id: "harvest-2")
    end
  end
end
