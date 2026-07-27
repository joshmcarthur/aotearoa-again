require "tmpdir"
require "vips"

ENV["PANGOCAIRO_BACKEND"] ||= "fontconfig"

class ComposeShareVideoJob
  # 9:16 short: full-bleed B&W detail → zoom out + soft diagonal wipe → letterbox + caption.
  class Renderer
    class Error < StandardError; end

    WIDTH = 1080
    HEIGHT = 1920
    MIN_TOP_BAR = 168
    MIN_BOTTOM_BAR = 260

    DEFAULTS = {
      fps: 30,
      hold_start_s: 1.2,
      motion_s: 4.0,
      hold_end_s: 9.8,
      caption_fade_s: 0.65,
      caption_lead_s: 0.45
    }.freeze

    def self.from_edition(edition, out_path:, **opts)
      variant = edition.variant
      candidate = variant.candidate
      raise Error, "edition #{edition.publish_on} missing colourised image" unless variant.colourised_image.attached?
      raise Error, "edition #{edition.publish_on} missing original image" unless candidate.original_image.attached?

      copy = Editions::Copy.new(edition.source_item)

      variant.colourised_image.blob.open do |colourised_file|
        candidate.original_image.blob.open do |original_file|
          new(
            original_path: original_file.path,
            colourised_path: colourised_file.path,
            out_path: out_path,
            title: copy.title,
            edition_label: MetaRows.edition_label(edition),
            meta_rows: MetaRows.for_source(edition.source_item, copy),
            **opts
          ).call
        end
      end
    end

    def initialize(original_path:, colourised_path:, out_path:, title: nil, edition_label: nil, meta_rows: nil, **opts)
      @original_path = original_path
      @colourised_path = colourised_path
      @out_path = Pathname(out_path)
      @title = title.to_s
      @edition_label = edition_label.to_s.presence
      @meta_rows = Array(meta_rows)
      @opts = DEFAULTS.merge(opts)
    end

    def call
      validate!
      prepare_stage!
      @out_path.dirname.mkpath

      Dir.mktmpdir("aotearoa-short-") do |dir|
        frame_dir = Pathname(dir)
        total_frames = write_frames(frame_dir)
        Encoder.new(fps: @opts[:fps]).encode!(
          frame_dir: frame_dir,
          total_frames: total_frames,
          out_path: @out_path
        )
      end

      @out_path
    rescue Vips::Error => e
      raise Error, e.message
    end

    private

    def validate!
      raise Error, "original image missing" unless @original_path.present? && File.exist?(@original_path)
      raise Error, "colourised image missing" unless @colourised_path.present? && File.exist?(@colourised_path)
      raise Error, "display font missing: #{TextPainter::DISPLAY_FONT_PATH}" unless TextPainter::DISPLAY_FONT_PATH.exist?
      raise Error, "body font missing: #{TextPainter::BODY_FONT_PATH}" unless TextPainter::BODY_FONT_PATH.exist?
      raise Error, "share audio missing: #{Encoder::AUDIO_PATH}" unless Encoder::AUDIO_PATH.exist?
      raise Error, "ffmpeg not found on PATH" unless Encoder.available?
    end

    def prepare_stage!
      @plates = Plates.new(
        original_path: @original_path,
        colourised_path: @colourised_path,
        frame_width: WIDTH
      ).prepare!

      stage = @plates.fit_stage(HEIGHT - MIN_TOP_BAR - MIN_BOTTOM_BAR)
      @layout = Letterbox.new(
        frame_width: WIDTH,
        frame_height: HEIGHT,
        min_top: MIN_TOP_BAR,
        min_bottom: MIN_BOTTOM_BAR
      ).layout_for(stage)

      @chrome = Chrome.new(
        width: WIDTH,
        height: HEIGHT,
        top_bar_h: @layout.top_bar_h,
        bottom_bar_h: @layout.bottom_bar_h,
        title: @title,
        edition_label: @edition_label,
        meta_rows: @meta_rows
      )
    end

    def write_frames(frame_dir)
      fps = @opts[:fps].to_f
      hold_start_s = @opts[:hold_start_s].to_f
      motion_s = @opts[:motion_s].to_f
      hold_end_s = @opts[:hold_end_s].to_f
      caption_fade_s = @opts[:caption_fade_s].to_f
      caption_lead_s = @opts[:caption_lead_s].to_f

      t_hold_start_end = hold_start_s
      t_motion_end = t_hold_start_end + motion_s
      t_caption_start = [ t_motion_end - caption_lead_s, t_hold_start_end ].max
      t_end = t_motion_end + hold_end_s

      feather = ComposeShareImageJob::DiagonalBlend::FEATHER
      center_bw = ComposeShareImageJob::DiagonalBlend.full_bw_center(feather: feather)
      center_colour = ComposeShareImageJob::DiagonalBlend.full_colour_center(feather: feather)

      total_frames = (t_end * fps).round
      total_frames.times do |i|
        layout_p, wipe_p, chrome_opacity = Timeline.sample_at(
          i / fps,
          t_hold_start_end:,
          t_motion_end:,
          t_caption_start:,
          caption_fade_s:,
          center_bw:,
          center_colour:
        )
        compose_frame(layout_p, wipe_p, chrome_opacity)
          .jpegsave(frame_dir.join(format("frame_%05d.jpg", i)).to_s, Q: 88)
      end
      total_frames
    end

    def compose_frame(layout_p, wipe_center, chrome_opacity)
      dest_h = Timeline.lerp(HEIGHT, @layout.stage_h, layout_p).round.clamp(@layout.stage_h, HEIGHT)
      dest_y = Timeline.lerp(0, @layout.top_bar_h, layout_p).round

      plate = ComposeShareImageJob::DiagonalBlend.apply(
        @plates.cover_crop(@plates.bw, WIDTH, dest_h),
        @plates.cover_crop(@plates.colour, WIDTH, dest_h),
        WIDTH,
        dest_h,
        center: wipe_center
      )

      canvas = solid(WIDTH, HEIGHT, Chrome::BAR_RGB).composite(plate, :over, x: 0, y: dest_y)
      return canvas if chrome_opacity <= 0.001

      overlay = chrome_opacity < 0.999 ? @chrome.apply_opacity(@chrome.overlay, chrome_opacity) : @chrome.overlay
      canvas.composite(overlay, :over, x: 0, y: 0)
    end

    def solid(width, height, rgb)
      Vips::Image.black(width, height, bands: 3)
        .new_from_image(rgb)
        .copy(interpretation: :srgb)
    end
  end
end
