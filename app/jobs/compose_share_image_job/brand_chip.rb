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
    BODY_FONT_PATH = Rails.root.join("app/assets/fonts/SourceSans3-Regular.ttf")
    DISPLAY_FONT_NAME = "Fraunces Bold"
    BODY_FONT_NAME = "Source Sans 3"

    TITLE_PX = 18
    BODY_PX = 12
    QR_SIZE = 40
    ICON_SIZE = 12
    PAD_X = 22
    GAP = 8
    STACK_GAP = 3

    SCRIM_RGB = [ 16, 14, 12 ].freeze
    TEXT_RGB = [ 243, 239, 230 ].freeze
    BODY_RGB = [ 232, 226, 214 ].freeze

    # Opacity from the bottom of the fade (1 = opaque).
    SCRIM_STOPS = [
      [ 0.0, 1.0 ],
      [ 0.28, 0.92 ],
      [ 0.48, 0.72 ],
      [ 0.72, 0.35 ],
      [ 1.0, 0.0 ]
    ].freeze

    INSTAGRAM_PATH = "M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"
    FACEBOOK_PATH = "M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"

    module_function

    def stamp(image, width, height, short_url, opacity: 1.0)
      opacity = opacity.to_f.clamp(0.0, 1.0)
      return image if opacity <= 0.0

      raise Composer::Error, "short URL missing" if short_url.blank?
      raise Composer::Error, "brand font missing: #{FONT_PATH}" unless FONT_PATH.exist?
      raise Composer::Error, "body font missing: #{BODY_FONT_PATH}" unless BODY_FONT_PATH.exist?

      fade_height = (height * 0.175).round.clamp(72, 160)
      content_height = (height * 0.1).round.clamp(48, 90)
      overlay = build_overlay(width, height, short_url, fade_height:, content_height:)
      if opacity < 1.0
        rgb = overlay.extract_band(0, n: 3)
        alpha = (overlay.extract_band(3).cast(:float) * opacity).cast(:uchar)
        overlay = rgb.bandjoin(alpha)
      end

      image
        .copy(interpretation: :srgb)
        .bandjoin(255)
        .composite(overlay, :over, x: 0, y: 0)
        .extract_band(0, n: 3)
        .copy(interpretation: :srgb)
    end

    def brand_text(max_width, max_height)
      raise Composer::Error, "brand font missing: #{FONT_PATH}" unless FONT_PATH.exist?

      text = Vips::Image.text(
        BRAND,
        font: DISPLAY_FONT_NAME,
        fontfile: FONT_PATH.to_s,
        width: max_width,
        height: max_height,
        rgba: true
      )
      alpha = text.extract_band(3)
      text
        .new_from_image(TEXT_RGB)
        .copy(interpretation: :srgb)
        .bandjoin(alpha)
    end

    def build_overlay(width, height, short_url, fade_height:, content_height:)
      overlay = transparent_canvas(width, height)
      overlay = overlay.composite(scrim(width, fade_height), :over, x: 0, y: height - fade_height)
      overlay.composite(content_row(width, short_url, content_height), :over, x: 0, y: height - content_height)
    end

    def scrim(width, fade_height)
      alphas = Array.new(fade_height) do |row|
        t_from_bottom = fade_height == 1 ? 1.0 : 1.0 - (row.to_f / (fade_height - 1))
        (interpolate_opacity(t_from_bottom) * 255).round.clamp(0, 255)
      end

      alpha_col = Vips::Image.new_from_array(alphas.map { |a| [ a ] })
        .cast(:uchar)
        .copy(interpretation: :"b-w")
      alpha = alpha_col.embed(0, 0, width, fade_height, extend: :copy)

      Vips::Image.black(width, fade_height, bands: 3)
        .new_from_image(SCRIM_RGB)
        .copy(interpretation: :srgb)
        .bandjoin(alpha)
    end

    def interpolate_opacity(t_from_bottom)
      t = t_from_bottom.to_f.clamp(0.0, 1.0)
      SCRIM_STOPS.each_cons(2) do |(t0, a0), (t1, a1)|
        next if t > t1
        return a0 if t1 == t0

        u = (t - t0) / (t1 - t0)
        return a0 + (a1 - a0) * u
      end
      SCRIM_STOPS.last.last
    end

    def content_row(width, short_url, content_h)
      qr = qr_rgba(short_url, QR_SIZE)
      text_max_w = width - PAD_X * 2 - QR_SIZE - GAP

      brand = paint_text(BRAND, width: text_max_w, font_height: TITLE_PX, style: :display, rgb: TEXT_RGB)
      icons = social_icons_row
      title_row = join_horizontal([ brand, icons ].compact, gap: 6)

      body = paint_text(
        "AI colourised · Alexander Turnbull Library, National Library of New Zealand · #{short_url}",
        width: text_max_w,
        font_height: BODY_PX,
        style: :body,
        rgb: BODY_RGB
      )

      stack_w = [ title_row.width, body.width ].max
      stack_h = title_row.height + STACK_GAP + body.height
      stack = transparent_canvas(stack_w, stack_h)
      stack = stack.composite(title_row, :over, x: 0, y: 0)
      stack = stack.composite(body, :over, x: 0, y: title_row.height + STACK_GAP)

      row = transparent_canvas(width, content_h)
      stack_y = ((content_h - stack.height) / 2.0).round.clamp(0, content_h)
      qr_y = ((content_h - qr.height) / 2.0).round.clamp(0, content_h)

      row = row.composite(stack, :over, x: PAD_X, y: stack_y)
      row.composite(qr, :over, x: width - PAD_X - qr.width, y: qr_y)
    end

    def social_icons_row
      icons = []
      icons << icon_rgba(INSTAGRAM_PATH) if AppConfig.instagram_url.present?
      icons << icon_rgba(FACEBOOK_PATH) if AppConfig.facebook_url.present?
      return if icons.empty?

      join_horizontal(icons, gap: 6)
    end

    def icon_rgba(path_d)
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{ICON_SIZE}" height="#{ICON_SIZE}" viewBox="0 0 24 24">
          <path fill="rgb(#{TEXT_RGB.join(',')})" d="#{path_d}"/>
        </svg>
      SVG
      icon = Vips::Image.svgload_buffer(svg)
      icon = icon.colourspace(:srgb) unless icon.interpretation == :srgb && icon.bands >= 3
      icon = icon.bandjoin(255) if icon.bands == 3
      if icon.width != ICON_SIZE || icon.height != ICON_SIZE
        icon = icon.thumbnail_image(ICON_SIZE, height: ICON_SIZE, size: :force)
      end
      icon.copy(interpretation: :srgb)
    end

    def join_horizontal(images, gap:)
      images = Array(images).compact
      return images.first if images.size == 1

      height = images.map(&:height).max
      width = images.sum(&:width) + gap * (images.size - 1)
      row = transparent_canvas(width, height)
      x = 0
      images.each_with_index do |image, index|
        y = ((height - image.height) / 2.0).round
        row = row.composite(image, :over, x: x, y: y)
        x += image.width + (index == images.size - 1 ? 0 : gap)
      end
      row
    end

    def paint_text(string, width:, font_height:, style:, rgb:, height: nil)
      font_name, font_path = font_for(style)
      opts = {
        font: "#{font_name} #{font_height}",
        fontfile: font_path.to_s,
        width: width,
        rgba: true,
        align: :low
      }
      opts[:height] = height if height

      text = Vips::Image.text(string.to_s, **opts)
      alpha = text.extract_band(3)
      text
        .new_from_image(rgb)
        .copy(interpretation: :srgb)
        .bandjoin(alpha)
    end

    def font_for(style)
      case style
      when :display then [ DISPLAY_FONT_NAME, FONT_PATH ]
      when :body then [ BODY_FONT_NAME, BODY_FONT_PATH ]
      else
        raise ArgumentError, "unknown text style: #{style.inspect}"
      end
    end

    def transparent_canvas(width, height)
      Vips::Image.black(width, height, bands: 3)
        .new_from_image([ 0, 0, 0 ])
        .copy(interpretation: :srgb)
        .bandjoin(0)
    end

    def qr_rgba(share_url, size)
      qrcode = RQRCode::QRCode.new(share_url)
      # as_png `size` below the module count yields a blank image.
      render_size = [ size, qrcode.modules.size ].max
      png = qrcode.as_png(
        border_modules: 0,
        color: "white",
        fill: "black",
        size: render_size
      )
      qr = Vips::Image.new_from_buffer(png.to_s, "")
      qr = qr.colourspace(:srgb) unless qr.interpretation == :srgb && qr.bands >= 3
      qr = qr.bandjoin(255) if qr.bands == 3
      if qr.width != size || qr.height != size
        qr = qr.thumbnail_image(size, height: size, size: :force)
      end
      qr.copy(interpretation: :srgb)
    end
  end
end
