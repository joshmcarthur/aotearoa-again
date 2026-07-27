require "stringio"
require "vips"

# Pango on macOS defaults to CoreText, which ignores `fontfile` and silently
# falls back to Helvetica. Force fontconfig before any Vips::Image.text call.
ENV["PANGOCAIRO_BACKEND"] ||= "fontconfig"

class ComposeShareImageJob
  class Composer
    class Error < StandardError; end

    MAX_WIDTH = 1200
    MAX_HEIGHT = 630
    FEATHER = DiagonalBlend::FEATHER
    BRAND = BrandChip::BRAND
    FONT_PATH = BrandChip::FONT_PATH

    ImageResult = Data.define(:io, :filename, :content_type)
    Result = Data.define(:composite, :share)

    def initialize(original_path:, colourised_path:, short_url:)
      @original_path = original_path
      @colourised_path = colourised_path
      @short_url = short_url
    end

    def call
      raise Error, "original image missing" unless @original_path.present? && File.exist?(@original_path)
      raise Error, "colourised image missing" unless @colourised_path.present? && File.exist?(@colourised_path)
      raise Error, "short URL missing" if @short_url.blank?

      bw = load_rgb(@original_path)
      colour = load_rgb(@colourised_path)

      width = colour.width
      height = colour.height
      bw = cover_crop(bw, width, height)
      colour = cover_crop(colour, width, height)

      scale = [ MAX_WIDTH.to_f / width, MAX_HEIGHT.to_f / height, 1.0 ].min
      if scale < 1.0
        width = (width * scale).round
        height = (height * scale).round
        bw = bw.thumbnail_image(width, height: height, size: :force)
        colour = colour.thumbnail_image(width, height: height, size: :force)
      end

      # Materialize once — we write the unbranded composite and a branded copy.
      blended = DiagonalBlend.apply(bw, colour, width, height).copy_memory
      stamped = BrandChip.stamp(blended, width, height, @short_url)

      Result.new(
        composite: jpeg_result(blended, "composite.jpg"),
        share: jpeg_result(stamped, "share.jpg")
      )
    rescue Vips::Error => e
      raise Error, e.message
    end

    private

    def jpeg_result(image, filename)
      ImageResult.new(
        io: StringIO.new(image.jpegsave_buffer(Q: 88)),
        filename: filename,
        content_type: "image/jpeg"
      )
    end

    def load_rgb(path)
      image = Vips::Image.new_from_file(path.to_s, access: :sequential)
      image = image.colourspace(:srgb) unless image.interpretation == :srgb && image.bands >= 3
      image.extract_band(0, n: 3).copy(interpretation: :srgb)
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

    # Kept for tests that probe brand_text via send.
    def brand_text(max_width, max_height)
      BrandChip.brand_text(max_width, max_height)
    end
  end
end
