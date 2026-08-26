require "vips"

class ComposeShareVideoJob
  # Letterbox bar typography (brand, edition label, plate title, NatLib meta).
  class Chrome
    MUTED_RGB = [ 168, 162, 150 ].freeze
    EMBER_RGB = [ 184, 106, 74 ].freeze
    SCRIM_STRENGTH = 0.32

    BRAND_FONT_SIZE = 51
    EDITION_DATE_FONT_SIZE = 30
    TITLE_FONT_SIZE = 26
    TITLE_LINE_HEIGHT = 1.5
    META_PRIMARY_FONT_SIZE = 32
    META_SECONDARY_FONT_SIZE = 26
    META_LINE_HEIGHT = 1.85
    PADDING_X = SafeAreas::PADDING_X
    PADDING_RIGHT = SafeAreas::PADDING_RIGHT

    def initialize(width:, height:, top_bar_h:, bottom_bar_h:, title:, edition_label:, meta_rows:)
      @width = width
      @height = height
      @top_bar_h = top_bar_h
      @bottom_bar_h = bottom_bar_h
      @title = title.to_s
      @edition_label = edition_label.to_s.presence
      @meta_rows = Array(meta_rows)
      @painter = TextPainter.new
    end

    def overlay
      @overlay ||= build_overlay.copy_memory
    end

    def apply_opacity(rgba, opacity)
      rgb = rgba.extract_band(0, n: 3)
      alpha = (rgba.extract_band(3).cast(:float) * opacity.to_f.clamp(0.0, 1.0)).cast(:uchar)
      rgb.bandjoin(alpha)
    end

    def scrim(opacity)
      @scrim_base ||= build_scrim.copy_memory
      opacity = opacity.to_f.clamp(0.0, 1.0)
      opacity >= 0.999 ? @scrim_base : apply_opacity(@scrim_base, opacity)
    end

    private

    def build_overlay
      overlay = transparent_canvas
      overlay = composite_top_bar(overlay)
      composite_bottom_caption(overlay)
    end

    def build_scrim
      overlay = transparent_canvas
      overlay = overlay.composite(bar_scrim(@top_bar_h, from_top: true), :over, x: 0, y: 0)
      overlay.composite(
        bar_scrim(@bottom_bar_h, from_top: false),
        :over,
        x: 0,
        y: @height - @bottom_bar_h
      )
    end

    def bar_scrim(height, from_top:)
      alphas = Array.new(height) do |row|
        t = height == 1 ? 1.0 : (from_top ? row.to_f / (height - 1) : 1.0 - (row.to_f / (height - 1)))
        (ComposeShareImageJob::BrandChip.interpolate_opacity(t) * SCRIM_STRENGTH * 255).round.clamp(0, 255)
      end

      alpha_col = Vips::Image.new_from_array(alphas.map { |a| [ a ] })
        .cast(:uchar)
        .copy(interpretation: :"b-w")
      alpha = alpha_col.embed(0, 0, @width, height, extend: :copy)

      Vips::Image.black(@width, height, bands: 3)
        .new_from_image(ComposeShareImageJob::BrandChip::SCRIM_RGB)
        .copy(interpretation: :srgb)
        .bandjoin(alpha)
    end

    def transparent_canvas
      Vips::Image.black(@width, @height, bands: 3)
        .new_from_image([ 0, 0, 0 ])
        .copy(interpretation: :srgb)
        .bandjoin(0)
    end

    def composite_top_bar(overlay)
      max_w = @width - PADDING_X - PADDING_RIGHT
      brand = @painter.paint(
        ComposeShareImageJob::BrandChip::BRAND,
        width: max_w,
        height: (BRAND_FONT_SIZE * 1.35).round,
        font_height: BRAND_FONT_SIZE,
        style: :display
      )
      edition = edition_label_image(max_w)

      stack_h = brand.height + (edition ? edition.height + 8 : 0)
      brand_y = top_brand_y(stack_h)
      overlay = overlay.composite(brand, :over, x: PADDING_X, y: brand_y)
      return overlay unless edition

      overlay.composite(edition, :over, x: PADDING_X, y: brand_y + brand.height + 8)
    end

    def top_brand_y(stack_h)
      safe_top = SafeAreas::PLATFORM_TOP_RESERVE
      extra = [ @top_bar_h - safe_top - stack_h, 0 ].max
      (safe_top + (extra / 2.0)).round
    end

    def edition_label_image(max_w)
      return if @edition_label.blank?

      @painter.paint(
        @edition_label,
        width: max_w,
        font_height: EDITION_DATE_FONT_SIZE,
        rgb: EMBER_RGB,
        style: :body
      )
    end

    def composite_bottom_caption(overlay)
      y = @height - @bottom_bar_h + 24
      max_w = @width - PADDING_X - PADDING_RIGHT
      caption_limit = SafeAreas.caption_bottom_limit(frame_height: @height)
      secondary_line_box = (META_SECONDARY_FONT_SIZE * META_LINE_HEIGHT).round

      overlay, y = composite_title(overlay, y, max_w, secondary_line_box)
      composite_meta_rows(overlay, y, max_w, caption_limit)
    end

    def composite_title(overlay, y, max_w, secondary_line_box)
      return [ overlay, y ] if @title.blank?

      title_line_box = (TITLE_FONT_SIZE * TITLE_LINE_HEIGHT).round
      title = @painter.paint(
        @title,
        width: max_w,
        height: title_line_box * 2,
        font_height: TITLE_FONT_SIZE,
        style: :display,
        spacing: (TITLE_FONT_SIZE * (TITLE_LINE_HEIGHT - 1.0)).round
      )
      overlay = overlay.composite(title, :over, x: PADDING_X, y: y)
      next_y = [ title.height, title_line_box ].max + y + (secondary_line_box * 0.35).round
      [ overlay, next_y ]
    end

    def composite_meta_rows(overlay, y, max_w, caption_limit)
      primary_line_box = (META_PRIMARY_FONT_SIZE * META_LINE_HEIGHT).round
      secondary_line_box = (META_SECONDARY_FONT_SIZE * META_LINE_HEIGHT).round

      @meta_rows.each do |row|
        size = row.primary ? META_PRIMARY_FONT_SIZE : META_SECONDARY_FONT_SIZE
        line_box = row.primary ? primary_line_box : secondary_line_box
        break if y + line_box > caption_limit - 12

        text = @painter.paint(
          row.text,
          width: max_w,
          font_height: size,
          rgb: MUTED_RGB,
          style: :body
        )
        overlay = overlay.composite(text, :over, x: PADDING_X, y: y)
        y += line_box
      end
      overlay
    end
  end
end
