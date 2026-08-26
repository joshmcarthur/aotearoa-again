require "tmpdir"
require "vips"

class ComposeShareVideoJob
  # 9:16 short: full-bleed B&W → letterbox + metadata → compare wipe on the card.
  class Renderer
    class Error < StandardError; end

    WIDTH = SafeAreas::FRAME_WIDTH
    HEIGHT = SafeAreas::FRAME_HEIGHT
    BACKDROP_BLUR = 28
    BACKDROP_DARKEN = 0.57

    # ~8s total: short enough for Reels/Shorts completion, long enough for wipe + chrome.
    DEFAULTS = {
      fps: 30,
      hold_bw_s: 0.8,
      letterbox_s: 1.2,
      wipe_s: 2.0,
      hold_end_s: 4.0,
      caption_fade_s: 0.65,
      caption_lead_s: 0.65
    }.freeze

    def self.from_edition(edition, out_path:, **opts)
      variant = edition.variant
      candidate = variant.candidate
      raise Error, "edition #{edition.publish_on} missing colourised image" unless variant.colourised_image.attached?
      raise Error, "edition #{edition.publish_on} missing original image" unless candidate.original_image.attached?

      copy = edition.copy

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

    def preview_frame(layout_p:, wipe_p:, chrome_opacity:)
      prepare_stage!
      compose_frame(layout_p, wipe_p, chrome_opacity)
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
        frame_width: SafeAreas.stage_max_width
      ).prepare!

      stage = @plates.fit_stage(SafeAreas.stage_max_height)
      @layout = Letterbox.new(
        frame_height: HEIGHT,
        min_top: SafeAreas::MIN_TOP_BAR,
        min_bottom: SafeAreas::MIN_BOTTOM_BAR,
        stage_inset_left: SafeAreas::STAGE_INSET_LEFT
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

      @bleed_bw = @plates.cover_crop(@plates.bw, WIDTH, HEIGHT).copy_memory
      @bleed_colour = @plates.cover_crop(@plates.colour, WIDTH, HEIGHT).copy_memory
      @blurred_bw = @bleed_bw.gaussblur(BACKDROP_BLUR).copy_memory
      @blurred_colour = @bleed_colour.gaussblur(BACKDROP_BLUR).copy_memory
    end

    def write_frames(frame_dir)
      fps = @opts[:fps].to_f
      schedule = Timeline.schedule_for(@opts)
      t_end = schedule.end

      total_frames = (t_end * fps).round
      total_frames.times do |i|
        layout_p, wipe_p, chrome_opacity = Timeline.sample_at(i / fps, schedule)
        compose_frame(layout_p, wipe_p, chrome_opacity)
          .jpegsave(frame_dir.join(format("frame_%05d.jpg", i)).to_s, Q: 88)
      end
      total_frames
    end

    def compose_frame(layout_p, wipe_p, chrome_opacity)
      if layout_p > 0.001
        dest_w = Timeline.lerp(WIDTH, @layout.stage_w, layout_p).round.clamp(@layout.stage_w, WIDTH)
        dest_h = Timeline.lerp(HEIGHT, @layout.stage_h, layout_p).round.clamp(@layout.stage_h, HEIGHT)
        dest_x = Timeline.lerp(0, @layout.stage_x, layout_p).round
        dest_y = Timeline.lerp(0, @layout.top_bar_h, layout_p).round
        card = ComposeShareImageJob::CompareHandle.apply(
          wiped_plate(dest_w, dest_h, wipe_p),
          progress: wipe_p
        )
        canvas = letterbox_backdrop(wipe_p, layout_p).composite(card, :over, x: dest_x, y: dest_y)
      else
        canvas = wiped_bleed(wipe_p)
      end

      return canvas if chrome_opacity <= 0.001

      canvas = canvas.composite(@chrome.scrim(chrome_opacity), :over, x: 0, y: 0)
      overlay = chrome_opacity < 0.999 ? @chrome.apply_opacity(@chrome.overlay, chrome_opacity) : @chrome.overlay
      canvas.composite(overlay, :over, x: 0, y: 0)
    end

    def letterbox_backdrop(wipe_p, layout_p)
      sharp = mix_images(@bleed_bw, @bleed_colour, wipe_p)
      blurred = mix_images(@blurred_bw, @blurred_colour, wipe_p)
      darken(mix_images(sharp, blurred, layout_p), BACKDROP_DARKEN * layout_p)
    end

    def wiped_bleed(wipe_p)
      mix_images(@bleed_bw, @bleed_colour, wipe_p)
    end

    def wiped_plate(width, height, wipe_p)
      wipe_pair(
        @plates.cover_crop(@plates.bw, width, height),
        @plates.cover_crop(@plates.colour, width, height),
        width,
        height,
        wipe_p
      )
    end

    def wipe_pair(bw, colour, width, height, wipe_p)
      if wipe_p <= 0.001
        bw
      elsif wipe_p >= 0.999
        colour
      else
        ComposeShareImageJob::VerticalWipe.apply(
          bw,
          colour,
          width,
          height,
          position: ComposeShareImageJob::VerticalWipe.position_for(wipe_p)
        )
      end
    end

    def mix_images(from, to, t)
      t = t.to_f.clamp(0.0, 1.0)
      return from if t <= 0.001
      return to if t >= 0.999

      ((from.cast(:float) * (1.0 - t)) + (to.cast(:float) * t)).cast(:uchar).copy(interpretation: :srgb)
    end

    def darken(image, amount)
      amount = amount.to_f.clamp(0.0, 1.0)
      return image if amount <= 0.001

      ((image.cast(:float) * (1.0 - amount))).cast(:uchar).copy(interpretation: :srgb)
    end
  end
end
