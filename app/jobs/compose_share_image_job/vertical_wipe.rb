require "vips"

class ComposeShareImageJob
  # Left-to-right B&W → colour wipe (matches the web compare slider).
  # +position+ is the blend line along x (0 = all B&W, 1 = all colour).
  module VerticalWipe
    FEATHER = 0.012

    module_function

    def apply(bw, colour, width, height, position:, feather: FEATHER)
      x = Vips::Image.xyz(width, height)[0].cast(:float) / [ width - 1, 1 ].max
      t = x.linear(-1, 1)
      half = feather / 2.0
      lo = position - half
      hi = position + half
      m = ((t - lo) / (hi - lo)).cast(:float)
      m = (m > 0).ifthenelse(m, 0)
      m = (m < 1).ifthenelse(m, 1)
      m = m * m * (m * -2 + 3)

      bw3 = bw.cast(:float)
      colour3 = colour.cast(:float)
      inv = m * -1 + 1
      (bw3 * inv + colour3 * m).cast(:uchar).copy(interpretation: :srgb)
    end

    def full_bw_position(feather: FEATHER)
      1.0 + feather
    end

    def full_colour_position(feather: FEATHER)
      0.0 - feather
    end

    def position_for(progress, feather: FEATHER)
      progress = progress.clamp(0.0, 1.0)
      full_bw_position(feather:) + (full_colour_position(feather:) - full_bw_position(feather:)) * progress
    end
  end
end
