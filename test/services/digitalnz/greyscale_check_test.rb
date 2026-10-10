require "test_helper"

module Digitalnz
  class GreyscaleCheckTest < ActiveSupport::TestCase
    test "accepts the mono plate fixture" do
      File.open(Rails.root.join("test/fixtures/files/mono_plate.jpg"), "rb") do |file|
        assert GreyscaleCheck.greyscale?(file)
      end
    end

    test "rejects a saturated colour image" do
      red = Vips::Image.black(16, 16, bands: 3).new_from_image([ 220, 20, 20 ]).copy(interpretation: :srgb)
      io = StringIO.new(red.jpegsave_buffer(Q: 90))
      assert_not GreyscaleCheck.greyscale?(io)
    end

    test "rewinds the IO after reading" do
      io = StringIO.new(File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg")))
      GreyscaleCheck.greyscale?(io)
      assert_equal 0, io.pos
    end
  end
end
