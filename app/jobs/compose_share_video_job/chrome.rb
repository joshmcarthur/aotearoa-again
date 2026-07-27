require "vips"

ENV["PANGOCAIRO_BACKEND"] ||= "fontconfig"

class ComposeShareVideoJob
  # Letterbox bar typography (brand, edition label, plate title, NatLib meta).
  class Chrome
    BAR_RGB = [ 28, 25, 20 ].freeze
    TEXT_RGB = [ 243, 239, 230 ].freeze
    MUTED_RGB = [ 168, 162, 150 ].freeze
    EMBER_RGB = [ 184, 106, 74 ].freeze

    DISPLAY_FONT_PATH = ComposeShareImageJob::BrandChip::FONT_PATH
    DISPLAY_FONT_NAME = "Fraunces Bold"
    BODY_FONT_PATH = Rails.root.join("app/assets/fonts/SourceSans3-Regular.ttf")
    BODY_FONT_NAME = "Source Sans 3"

    BRAND_FONT_SIZE = 51
    EDITION_DATE_FONT_SIZE = 30
    TITLE_FONT_SIZE = 26
    TITLE_LINE_HEIGHT = 1.5
    META_PRIMARY_FONT_SIZE = 32
    META_SECONDARY_FONT_SIZE = 26
    META_LINE_HEIGHT = 1.85

    def initialize(width:, height:, top_bar_h:, bottom_bar_h:, title:, edition_label:, meta_rows:)
      @width = width
      @height = height
      @top_bar_h = top_bar_h
      @bottom_bar_h = bottom_bar_h
      @title = title.to_s
      @edition_label = edition_label.to_s.presence
      @meta_rows = Array(meta_rows)
    end

    def overlay
      @overlay ||= build_overlay.copy_memory
    end

    def apply_opacity(rgba, opacity)
      rgb = rgba.extract_band(0, n: 3)
      alpha = (rgba.extract_band(3).cast(:float) * opacity.to_f.clamp(0.0, 1.0)).cast(:uchar)
      rgb.bandjoin(alpha)
    end

    private

    def build_overlay
      overlay = Vips::Image.black(@width, @height, bands: 3)
        .new_from_image([ 0, 0, 0 ])
        .copy(interpretation: :srgb)
        .bandjoin(0)

      padding_x = 40
      max_top_w = @width - padding_x * 2
      brand_box_h = (BRAND_FONT_SIZE * 1.35).round
      brand = colored_text(
        ComposeShareImageJob::BrandChip::BRAND,
        width: max_top_w,
        height: brand_box_h,
        font_height: BRAND_FONT_SIZE,
        style: :display
      )

      edition = nil
      if @edition_label.present?
        edition = colored_text(
          @edition_label,
          width: max_top_w,
          font_height: EDITION_DATE_FONT_SIZE,
          rgb: EMBER_RGB,
          style: :body
        )
      end

      stack_h = brand.height + (edition ? edition.height + 8 : 0)
      brand_y = ((@top_bar_h - stack_h) / 2.0).round.clamp(0, @top_bar_h)
      overlay = overlay.composite(brand, :over, x: padding_x, y: brand_y)
      if edition
        edition_y = brand_y + brand.height + 8
        overlay = overlay.composite(edition, :over, x: padding_x, y: edition_y)
      end

      y = @height - @bottom_bar_h + 24
      max_w = @width - padding_x * 2
      title_line_box = (TITLE_FONT_SIZE * TITLE_LINE_HEIGHT).round
      primary_line_box = (META_PRIMARY_FONT_SIZE * META_LINE_HEIGHT).round
      secondary_line_box = (META_SECONDARY_FONT_SIZE * META_LINE_HEIGHT).round

      if @title.present?
        title_spacing = (TITLE_FONT_SIZE * (TITLE_LINE_HEIGHT - 1.0)).round
        title = colored_text(
          @title,
          width: max_w,
          height: title_line_box * 2,
          font_height: TITLE_FONT_SIZE,
          style: :display,
          spacing: title_spacing
        )
        overlay = overlay.composite(title, :over, x: padding_x, y: y)
        y += [ title.height, title_line_box ].max + (secondary_line_box * 0.35).round
      end

      @meta_rows.each do |row|
        size = row.primary ? META_PRIMARY_FONT_SIZE : META_SECONDARY_FONT_SIZE
        line_box = row.primary ? primary_line_box : secondary_line_box
        break if y + line_box > @height - 12

        text = colored_text(
          row.text,
          width: max_w,
          font_height: size,
          rgb: MUTED_RGB,
          style: :body
        )
        overlay = overlay.composite(text, :over, x: padding_x, y: y)
        y += line_box
      end
      overlay
    end

    def colored_text(string, width:, font_height:, height: nil, rgb: TEXT_RGB, style: :display, spacing: nil)
      font_name, font_path =
        case style
        when :display then [ DISPLAY_FONT_NAME, DISPLAY_FONT_PATH ]
        when :body then [ BODY_FONT_NAME, BODY_FONT_PATH ]
        else
          raise Renderer::Error, "unknown text style: #{style.inspect}"
        end

      opts = {
        font: "#{font_name} #{font_height}",
        fontfile: font_path.to_s,
        width: width,
        rgba: true,
        align: :low
      }
      opts[:height] = height if height
      opts[:spacing] = spacing if spacing

      text = Vips::Image.text(string.to_s, **opts)
      alpha = text.extract_band(3)
      text
        .new_from_image(rgb)
        .copy(interpretation: :srgb)
        .bandjoin(alpha)
    end
  end
end
