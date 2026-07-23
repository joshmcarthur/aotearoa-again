require "rqrcode"
require "stringio"
require "vips"

# Pango on macOS defaults to CoreText, which ignores `fontfile` and silently
# falls back to Helvetica. Force fontconfig before any Vips::Image.text call.
ENV["PANGOCAIRO_BACKEND"] ||= "fontconfig"

module ShareImages
  class Composer
    class Error < StandardError; end

    MAX_WIDTH = 1200
    MAX_HEIGHT = 630
    FEATHER = 0.12
    BRAND = "Aotearoa, Again"
    FONT_PATH = Rails.root.join("app/assets/fonts/Fraunces-Bold.ttf")

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
      blended = soft_diagonal_blend(bw, colour, width, height).copy_memory
      stamped = add_corner_chip(blended, width, height)

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

    def soft_diagonal_blend(bw, colour, width, height)
      x = Vips::Image.xyz(width, height)[0].cast(:float) / [ width - 1, 1 ].max
      y = Vips::Image.xyz(width, height)[1].cast(:float) / [ height - 1, 1 ].max
      t = (x + y) / 2.0

      half = FEATHER / 2.0
      lo = 0.5 - half
      hi = 0.5 + half
      m = ((t - lo) / (hi - lo)).cast(:float)
      m = (m > 0).ifthenelse(m, 0)
      m = (m < 1).ifthenelse(m, 1)
      m = m * m * (m * -2 + 3)

      bw3 = bw.cast(:float)
      colour3 = colour.cast(:float)
      inv = m * -1 + 1
      (bw3 * inv + colour3 * m).cast(:uchar).copy(interpretation: :srgb)
    end

    def add_corner_chip(image, width, height)
      qr_size = (width * 0.08).round.clamp(48, 96)
      padding = (width * 0.02).round.clamp(8, 24)
      text_max_w = (width * 0.42).round

      qr = qr_rgba(qr_size)
      text = brand_text(text_max_w, (qr_size * 0.7).round)

      chip_h = qr_size + padding * 2
      chip_w = text.width + qr.width + padding * 3
      chip_w = [ chip_w, width - padding * 2 ].min

      chip = Vips::Image.black(chip_w, chip_h, bands: 3)
        .new_from_image([ 28, 25, 20 ])
        .copy(interpretation: :srgb)
        .bandjoin(210)

      text_x = padding
      text_y = ((chip_h - text.height) / 2.0).round
      qr_x = chip_w - qr.width - padding
      qr_y = padding

      chip = chip.composite(text, :over, x: text_x, y: text_y)
      chip = chip.composite(qr, :over, x: qr_x, y: qr_y)

      x = padding
      y = height - chip_h - padding
      image
        .copy(interpretation: :srgb)
        .bandjoin(255)
        .composite(chip, :over, x: x, y: y)
        .extract_band(0, n: 3)
        .copy(interpretation: :srgb)
    end

    def brand_text(max_width, max_height)
      raise Error, "brand font missing: #{FONT_PATH}" unless FONT_PATH.exist?

      text = Vips::Image.text(
        BRAND,
        font: "Fraunces Bold",
        fontfile: FONT_PATH.to_s,
        width: max_width,
        height: max_height,
        rgba: true
      )
      alpha = text.extract_band(3)
      text
        .new_from_image([ 243, 239, 230 ])
        .copy(interpretation: :srgb)
        .bandjoin(alpha)
    end

    def qr_rgba(size)
      png = RQRCode::QRCode.new(@short_url).as_png(
        bit_depth: 1,
        border_modules: 1,
        color: "black",
        fill: "white",
        module_px_size: 6,
        size: size
      )
      qr = Vips::Image.new_from_buffer(png.to_s, "")
      qr = qr.colourspace(:srgb) if qr.bands < 3
      qr
        .extract_band(0, n: 3)
        .thumbnail_image(size, height: size, size: :force)
        .copy(interpretation: :srgb)
        .bandjoin(255)
    end
  end
end
