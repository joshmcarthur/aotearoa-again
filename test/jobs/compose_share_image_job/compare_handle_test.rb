require "test_helper"

class ComposeShareImageJob
  class CompareHandleTest < ActiveSupport::TestCase
    setup do
      @base = solid(0, 0, 0)
    end

    test "leaves the plate unchanged at the wipe start and end" do
      [ 0.0, 1.0 ].each do |progress|
        out = CompareHandle.apply(@base, progress:)
        pixel = out.getpoint(32, 32)
        assert_in_delta 0, pixel[0], 1
        assert_in_delta 0, pixel[1], 1
        assert_in_delta 0, pixel[2], 1
      end
    end

    test "draws a near-white vertical line at the mid wipe" do
      out = CompareHandle.apply(@base, progress: 0.5)
      line = out.getpoint(32, 8)
      assert_operator line[0], :>, 200
      assert_operator line[1], :>, 200
      assert_operator line[2], :>, 200
    end

    test "paints the sea-green knob at the mid-line centre" do
      out = CompareHandle.apply(@base, progress: 0.5)
      knob = out.getpoint(32, 32)
      assert_in_delta CompareHandle::KNOB_FILL[0], knob[0], 8
      assert_in_delta CompareHandle::KNOB_FILL[1], knob[1], 8
      assert_in_delta CompareHandle::KNOB_FILL[2], knob[2], 8
    end

    private

    def solid(r, g, b)
      Vips::Image.black(64, 64, bands: 3)
        .new_from_image([ r, g, b ])
        .copy(interpretation: :srgb)
    end
  end
end
