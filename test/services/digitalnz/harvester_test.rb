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

    class SequenceSelector
      def initialize(records)
        @records = records.dup
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

    test "creates a candidate from the selected record" do
      record = photograph_record("harvest-1")
      body = File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg"))
      harvester = Harvester.new(
        selector: FakeSelector.new(record),
        downloader: FakeDownloader.new(body)
      )

      candidate = harvester.call

      assert_not_nil candidate
      assert_equal "pending_review", candidate.status
      assert candidate.original_image.attached?
      assert_equal "Auckland Libraries", candidate.source_item.content_partner
      assert_not candidate.source_item.discarded?
    end

    test "discards a colour photograph and does not create a candidate" do
      record = photograph_record("colour-1")
      harvester = Harvester.new(
        selector: FakeSelector.new(record),
        downloader: FakeDownloader.new(jpeg_from_rgb(20, 20, 220))
      )

      assert_nil harvester.call
      source = SourceItem.find_by(digitalnz_id: "colour-1")
      assert source.discarded?
      assert_equal 0, source.candidates.count
    end

    test "retries after a colour photograph and harvests the next mono record" do
      colour = photograph_record("colour-2", title: "Blue lake")
      mono = photograph_record("harvest-2", title: "Queen Street")
      bodies = {
        "https://example.com/colour-2.jpg" => jpeg_from_rgb(20, 20, 220),
        "https://example.com/harvest-2.jpg" => File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg"))
      }

      harvester = Harvester.new(
        selector: SequenceSelector.new([ colour, mono ]),
        downloader: lambda do |url|
          {
            io: StringIO.new(bodies.fetch(url)),
            filename: "original.jpg",
            content_type: "image/jpeg"
          }
        end
      )

      candidate = harvester.call

      assert_equal "harvest-2", candidate.source_item.digitalnz_id
      assert SourceItem.find_by(digitalnz_id: "colour-2").discarded?
    end

    private

    def photograph_record(id, title: "Queen Street")
      {
        "id" => id,
        "title" => title,
        "description" => [ "Looking north" ],
        "rights" => [ "No known copyright restrictions" ],
        "usage" => [ "Modify", "Share", "Use commercially" ],
        "content_partner" => [ "Auckland Libraries" ],
        "landing_url" => "https://digitalnz.org/records/#{id}",
        "large_thumbnail_url" => [ "https://example.com/#{id}.jpg" ],
        "dc_type" => [ "Photograph - print" ],
        "subject" => [ "Streets" ]
      }
    end

    def jpeg_from_rgb(red, green, blue)
      image = Vips::Image.black(16, 16, bands: 3).new_from_image([ red, green, blue ]).copy(interpretation: :srgb)
      image.jpegsave_buffer(Q: 90)
    end
  end
end
