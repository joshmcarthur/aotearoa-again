require "test_helper"

module ShareImages
  class ComposerTest < ActiveSupport::TestCase
    test "composites a branded share jpeg within og bounds" do
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")

      result = Composer.new(
        original_path: path,
        colourised_path: path,
        short_url: "http://www.example.com/s/abc123"
      ).call

      assert_equal "share.jpg", result.filename
      assert_equal "image/jpeg", result.content_type
      assert result.io.size.positive?

      image = Vips::Image.new_from_buffer(result.io.string, "")
      assert_operator image.width, :<=, Composer::MAX_WIDTH
      assert_operator image.height, :<=, Composer::MAX_HEIGHT
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
