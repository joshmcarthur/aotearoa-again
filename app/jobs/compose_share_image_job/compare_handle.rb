require "vips"

class ComposeShareImageJob
  # Web compare-slider chrome: vertical hairline + sea-green knob.
  module CompareHandle
    LINE_WIDTH = 4
    KNOB_SIZE = 40
    LINE_RGB = [ 255, 255, 255 ].freeze
    LINE_ALPHA = 230 # white/90
    KNOB_FILL = [ 31, 77, 74 ].freeze # --color-sea
    KNOB_STROKE = [ 255, 255, 255 ].freeze
    KNOB_STROKE_WIDTH = 2

    module_function

    def apply(image, progress:, feather: VerticalWipe::FEATHER)
      progress = progress.to_f
      return image if progress <= 0.001 || progress >= 0.999

      width = image.width
      height = image.height
      x = line_x(progress, width, feather:)

      overlay = transparent_canvas(width, height)
      overlay = composite_clamped(overlay, line(height), x: x - LINE_WIDTH / 2, y: 0)
      overlay = composite_clamped(
        overlay,
        knob,
        x: x - KNOB_SIZE / 2,
        y: (height - KNOB_SIZE) / 2
      )

      plate = image.bands == 3 ? image.bandjoin(255) : image
      plate.composite(overlay, :over).extract_band(0, n: 3).copy(interpretation: :srgb)
    end

    def line_x(progress, width, feather: VerticalWipe::FEATHER)
      position = VerticalWipe.position_for(progress, feather:)
      ((1.0 - position) * (width - 1)).round
    end

    def line(height)
      Vips::Image.black(LINE_WIDTH, height, bands: 3)
        .new_from_image(LINE_RGB)
        .copy(interpretation: :srgb)
        .bandjoin(LINE_ALPHA)
    end

    def knob
      size = KNOB_SIZE
      r = size / 2.0
      inner = r - KNOB_STROKE_WIDTH
      x = Vips::Image.xyz(size, size)[0].cast(:float)
      y = Vips::Image.xyz(size, size)[1].cast(:float)
      dist = ((x - r)**2 + (y - r)**2)**0.5

      fill = disc(size, KNOB_FILL, (dist < inner).ifthenelse(255, 0))
      stroke = disc(size, KNOB_STROKE, ((dist < r) & (dist >= inner)).ifthenelse(255, 0))
      fill.composite(stroke, :over)
    end

    def disc(size, rgb, alpha)
      Vips::Image.black(size, size, bands: 3)
        .new_from_image(rgb)
        .copy(interpretation: :srgb)
        .bandjoin(alpha.cast(:uchar))
    end

    def transparent_canvas(width, height)
      Vips::Image.black(width, height, bands: 3)
        .new_from_image([ 0, 0, 0 ])
        .copy(interpretation: :srgb)
        .bandjoin(0)
    end

    def composite_clamped(base, layer, x:, y:)
      x = x.round
      y = y.round
      return base if x >= base.width || y >= base.height
      return base if x + layer.width <= 0 || y + layer.height <= 0

      base.composite(layer, :over, x: x, y: y)
    end
  end
end
