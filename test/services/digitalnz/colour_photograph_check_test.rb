require "test_helper"

module Digitalnz
  class ColourPhotographCheckTest < ActiveSupport::TestCase
    test "accepts the mono plate fixture" do
      File.open(Rails.root.join("test/fixtures/files/mono_plate.jpg"), "rb") do |file|
        assert_not ColourPhotographCheck.colour_photograph?(file)
      end
    end

    test "accepts a warm sepia original" do
      io = jpeg_from_rgb(160, 120, 80)
      assert_not ColourPhotographCheck.colour_photograph?(io)
    end

    test "rejects a saturated blue image" do
      io = jpeg_from_rgb(20, 20, 220)
      assert ColourPhotographCheck.colour_photograph?(io)
    end

    test "rejects a saturated green image" do
      io = jpeg_from_rgb(20, 220, 20)
      assert ColourPhotographCheck.colour_photograph?(io)
    end

    test "rewinds the IO after reading" do
      io = StringIO.new(File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg")))
      ColourPhotographCheck.colour_photograph?(io)
      assert_equal 0, io.pos
    end

    private

    def jpeg_from_rgb(red, green, blue)
      image = Vips::Image.black(16, 16, bands: 3).new_from_image([ red, green, blue ]).copy(interpretation: :srgb)
      StringIO.new(image.jpegsave_buffer(Q: 90))
    end
  end
end
