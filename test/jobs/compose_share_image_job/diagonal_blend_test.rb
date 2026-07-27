require "test_helper"

class ComposeShareImageJob
  class DiagonalBlendTest < ActiveSupport::TestCase
    test "full_bw_center yields only the B&W plate" do
      bw = solid(10, 20, 30)
      colour = solid(200, 210, 220)
      out = DiagonalBlend.apply(
        bw, colour, 64, 64,
        center: DiagonalBlend.full_bw_center
      )
      assert_pixels_close out, 10, 20, 30
    end

    test "full_colour_center yields only the colour plate" do
      bw = solid(10, 20, 30)
      colour = solid(200, 210, 220)
      out = DiagonalBlend.apply(
        bw, colour, 64, 64,
        center: DiagonalBlend.full_colour_center
      )
      assert_pixels_close out, 200, 210, 220
    end

    private

    def solid(r, g, b)
      Vips::Image.black(64, 64, bands: 3)
        .new_from_image([ r, g, b ])
        .copy(interpretation: :srgb)
    end

    def assert_pixels_close(image, r, g, b)
      avg = image.avg
      pixel = image.getpoint(32, 32)
      assert_in_delta r, pixel[0], 1
      assert_in_delta g, pixel[1], 1
      assert_in_delta b, pixel[2], 1
      assert_operator avg, :>=, 0
    end
  end
end
