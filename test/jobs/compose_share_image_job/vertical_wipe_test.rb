require "test_helper"

class ComposeShareImageJob
  class VerticalWipeTest < ActiveSupport::TestCase
    test "full_bw_position yields only the B&W plate" do
      bw = solid(10, 20, 30)
      colour = solid(200, 210, 220)
      out = VerticalWipe.apply(
        bw, colour, 64, 64,
        position: VerticalWipe.full_bw_position
      )
      assert_pixels_close out, 10, 20, 30
    end

    test "full_colour_position yields only the colour plate" do
      bw = solid(10, 20, 30)
      colour = solid(200, 210, 220)
      out = VerticalWipe.apply(
        bw, colour, 64, 64,
        position: VerticalWipe.full_colour_position
      )
      assert_pixels_close out, 200, 210, 220
    end

    test "mid wipe shows colour on the left and B&W on the right" do
      bw = solid(0, 0, 0)
      colour = solid(255, 255, 255)
      out = VerticalWipe.apply(
        bw, colour, 64, 64,
        position: VerticalWipe.position_for(0.5)
      )
      left = out.getpoint(8, 32)
      right = out.getpoint(56, 32)
      assert_operator left.sum, :>, right.sum
    end

    private

    def solid(r, g, b)
      Vips::Image.black(64, 64, bands: 3)
        .new_from_image([ r, g, b ])
        .copy(interpretation: :srgb)
    end

    def assert_pixels_close(image, r, g, b)
      pixel = image.getpoint(32, 32)
      assert_in_delta r, pixel[0], 1
      assert_in_delta g, pixel[1], 1
      assert_in_delta b, pixel[2], 1
    end
  end
end
