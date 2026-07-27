require "chunky_png"
require "rqrcode"
require "vips"

# Pango on macOS defaults to CoreText, which ignores `fontfile` and silently
# falls back to Helvetica. Force fontconfig before any Vips::Image.text call.
ENV["PANGOCAIRO_BACKEND"] ||= "fontconfig"

class ComposeShareImageJob
  module BrandChip
    BRAND = "Aotearoa, Again"
    FONT_PATH = Rails.root.join("app/assets/fonts/Fraunces-Bold.ttf")

    module_function

    # Returns an RGBA image of the brand chip (text + QR), sized for +width+.
    def build(width, short_url)
      raise Composer::Error, "short URL missing" if short_url.blank?
      raise Composer::Error, "brand font missing: #{FONT_PATH}" unless FONT_PATH.exist?

      qr_size = (width * 0.08).round.clamp(48, 96)
      padding = (width * 0.02).round.clamp(8, 24)
      text_max_w = (width * 0.42).round

      qr = qr_rgba(short_url, qr_size)
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
      chip.composite(qr, :over, x: qr_x, y: qr_y)
    end

    def stamp(image, width, height, short_url, opacity: 1.0)
      opacity = opacity.to_f.clamp(0.0, 1.0)
      return image if opacity <= 0.0

      chip = build(width, short_url)
      if opacity < 1.0
        rgb = chip.extract_band(0, n: 3)
        alpha = (chip.extract_band(3).cast(:float) * opacity).cast(:uchar)
        chip = rgb.bandjoin(alpha)
      end

      padding = (width * 0.02).round.clamp(8, 24)
      x = padding
      y = height - chip.height - padding
      image
        .copy(interpretation: :srgb)
        .bandjoin(255)
        .composite(chip, :over, x: x, y: y)
        .extract_band(0, n: 3)
        .copy(interpretation: :srgb)
    end

    def brand_text(max_width, max_height)
      raise Composer::Error, "brand font missing: #{FONT_PATH}" unless FONT_PATH.exist?

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

    def qr_rgba(share_url, size)
      png = RQRCode::QRCode.new(share_url).as_png(
        border_modules: 0,
        color: "white",
        fill: ChunkyPNG::Color::TRANSPARENT,
        size: size
      )
      qr = Vips::Image.new_from_buffer(png.to_s, "")
      unless qr.interpretation == :srgb && qr.bands >= 3
        qr = qr.colourspace(:srgb)
      end
      qr = qr.bandjoin(255) if qr.bands == 3
      if qr.width != size || qr.height != size
        qr = qr.thumbnail_image(size, height: size, size: :force)
      end
      qr.copy(interpretation: :srgb)
    end
  end
end
