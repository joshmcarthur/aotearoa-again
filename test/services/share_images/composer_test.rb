require "test_helper"

module ShareImages
  class ComposerTest < ActiveSupport::TestCase
    test "composites branded share and unbranded composite jpegs within og bounds" do
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")

      result = Composer.new(
        original_path: path,
        colourised_path: path,
        short_url: "http://www.example.com/s/abc123"
      ).call

      assert_equal "composite.jpg", result.composite.filename
      assert_equal "share.jpg", result.share.filename
      assert_equal "image/jpeg", result.composite.content_type
      assert_equal "image/jpeg", result.share.content_type
      assert result.composite.io.size.positive?
      assert result.share.io.size.positive?

      composite = Vips::Image.new_from_buffer(result.composite.io.string, "")
      share = Vips::Image.new_from_buffer(result.share.io.string, "")
      assert_operator composite.width, :<=, Composer::MAX_WIDTH
      assert_operator composite.height, :<=, Composer::MAX_HEIGHT
      assert_equal composite.width, share.width
      assert_equal composite.height, share.height
      # Brand chip should change pixels vs the unbranded composite.
      assert_not_equal result.composite.io.string, result.share.io.string
    end

    test "raises when original is missing" do
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")

      assert_raises(Composer::Error) do
        Composer.new(
          original_path: "/tmp/missing-original.jpg",
          colourised_path: path,
          short_url: "http://www.example.com/s/abc123"
        ).call
      end
    end
  end
end
