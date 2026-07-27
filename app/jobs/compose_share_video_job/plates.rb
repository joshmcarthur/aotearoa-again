require "vips"

class ComposeShareVideoJob
  # Loads and prepares matched B&W / colour working plates for framing.
  class Plates
    def initialize(original_path:, colourised_path:, frame_width:)
      @original_path = original_path
      @colourised_path = colourised_path
      @frame_width = frame_width
    end

    def prepare!
      colour = load_rgb(@colourised_path)
      bw = cover_crop(load_rgb(@original_path), colour.width, colour.height)
      colour = cover_crop(colour, colour.width, colour.height)

      work_w = [ colour.width, @frame_width * 2 ].max
      scale = work_w.to_f / colour.width
      work_h = (colour.height * scale).round
      @bw = bw.thumbnail_image(work_w, height: work_h, size: :force).copy_memory
      @colour = colour.thumbnail_image(work_w, height: work_h, size: :force).copy_memory
      self
    end

    attr_reader :bw, :colour

    def fit_stage(max_height)
      scale = [ @frame_width.to_f / @colour.width, max_height.to_f / @colour.height ].min
      w = (@colour.width * scale).round.clamp(1, @frame_width)
      h = (@colour.height * scale).round.clamp(1, max_height)
      @colour.thumbnail_image(w, height: h, size: :force)
    end

    def cover_crop(image, target_w, target_h)
      scale = [ target_w.to_f / image.width, target_h.to_f / image.height ].max
      resized = image.resize(scale)
      left = [ ((resized.width - target_w) / 2.0).floor, 0 ].max
      top = [ ((resized.height - target_h) / 2.0).floor, 0 ].max
      crop_w = [ target_w, resized.width ].min
      crop_h = [ target_h, resized.height ].min
      resized.crop(left, top, crop_w, crop_h)
    end

    private

    def load_rgb(path)
      image = Vips::Image.new_from_file(path.to_s, access: :sequential)
      image = image.colourspace(:srgb) unless image.interpretation == :srgb && image.bands >= 3
      image.extract_band(0, n: 3).copy(interpretation: :srgb)
    end
  end
end
