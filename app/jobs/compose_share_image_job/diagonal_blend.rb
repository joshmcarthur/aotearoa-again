require "vips"

class ComposeShareImageJob
  # Soft diagonal B&W → colour blend for still share images.
  # +center+ is the midpoint of the feathered band along t = (x + y) / 2
  # (0 top-left … 1 bottom-right). Raise center toward 1+feather for more B&W;
  # lower toward 0−feather for more colour.
  module DiagonalBlend
    FEATHER = 0.12

    module_function

    def apply(bw, colour, width, height, center: 0.5, feather: FEATHER)
      x = Vips::Image.xyz(width, height)[0].cast(:float) / [ width - 1, 1 ].max
      y = Vips::Image.xyz(width, height)[1].cast(:float) / [ height - 1, 1 ].max
      t = (x + y) / 2.0

      half = feather / 2.0
      lo = center - half
      hi = center + half
      m = ((t - lo) / (hi - lo)).cast(:float)
      m = (m > 0).ifthenelse(m, 0)
      m = (m < 1).ifthenelse(m, 1)
      m = m * m * (m * -2 + 3)

      bw3 = bw.cast(:float)
      colour3 = colour.cast(:float)
      inv = m * -1 + 1
      (bw3 * inv + colour3 * m).cast(:uchar).copy(interpretation: :srgb)
    end

    def full_bw_center(feather: FEATHER)
      1.0 + feather
    end

    def full_colour_center(feather: FEATHER)
      0.0 - feather
    end
  end
end
