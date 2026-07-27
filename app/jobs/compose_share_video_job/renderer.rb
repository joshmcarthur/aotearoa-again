require "open3"
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
      raise Error, "original image missing" unless @original_path.present? && File.exist?(@original_path)
      raise Error, "colourised image missing" unless @colourised_path.present? && File.exist?(@colourised_path)
      raise Error, "display font missing: #{Chrome::DISPLAY_FONT_PATH}" unless Chrome::DISPLAY_FONT_PATH.exist?
      raise Error, "body font missing: #{Chrome::BODY_FONT_PATH}" unless Chrome::BODY_FONT_PATH.exist?
      raise Error, "ffmpeg not found on PATH" unless ffmpeg_available?

      colour = load_rgb(@colourised_path)
      bw = cover_crop(load_rgb(@original_path), colour.width, colour.height)
      colour = cover_crop(colour, colour.width, colour.height)

      work_w = [ colour.width, WIDTH * 2 ].max
      scale = work_w.to_f / colour.width
      work_h = (colour.height * scale).round
      @bw = bw.thumbnail_image(work_w, height: work_h, size: :force).copy_memory
      @colour = colour.thumbnail_image(work_w, height: work_h, size: :force).copy_memory

      stage = fit_stage(@colour)
      @stage_w = stage.width
      @stage_h = stage.height
      remainder = HEIGHT - @stage_h
      raise Error, "image too tall for letterboxed short layout" if remainder < MIN_TOP_BAR + MIN_BOTTOM_BAR

      @top_bar_h = [ MIN_TOP_BAR, (remainder * 0.34).round ].max
      @bottom_bar_h = remainder - @top_bar_h
      if @bottom_bar_h < MIN_BOTTOM_BAR
        @bottom_bar_h = MIN_BOTTOM_BAR
        @top_bar_h = remainder - @bottom_bar_h
      end

      @chrome = Chrome.new(
        width: WIDTH,
        height: HEIGHT,
        top_bar_h: @top_bar_h,
        bottom_bar_h: @bottom_bar_h,
        title: @title,
        edition_label: @edition_label,
        meta_rows: @meta_rows
      )

      @out_path.dirname.mkpath
      Dir.mktmpdir("aotearoa-short-") do |dir|
        frame_dir = Pathname(dir)
        total_frames = write_frames(frame_dir)
        encode(frame_dir, total_frames)
      end

      @out_path
    rescue Vips::Error => e
      raise Error, e.message
    end

    private

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
        time = i / fps
        layout_p, wipe_p, chrome_opacity = Timeline.sample_at(
          time,
          t_hold_start_end:,
          t_motion_end:,
          t_caption_start:,
          caption_fade_s:,
          center_bw:,
          center_colour:
        )

        frame = compose_frame(layout_p, wipe_p, chrome_opacity)
        path = frame_dir.join(format("frame_%05d.jpg", i))
        frame.jpegsave(path.to_s, Q: 88)
      end
      total_frames
    end

    def compose_frame(layout_p, wipe_center, chrome_opacity)
      dest_h = Timeline.lerp(HEIGHT, @stage_h, layout_p).round.clamp(@stage_h, HEIGHT)
      dest_y = Timeline.lerp(0, @top_bar_h, layout_p).round
      dest_w = WIDTH

      bw_v = cover_crop(@bw, dest_w, dest_h)
      colour_v = cover_crop(@colour, dest_w, dest_h)
      plate = ComposeShareImageJob::DiagonalBlend.apply(bw_v, colour_v, dest_w, dest_h, center: wipe_center)

      canvas = solid(WIDTH, HEIGHT, Chrome::BAR_RGB)
      canvas = canvas.composite(plate, :over, x: 0, y: dest_y)
      return canvas if chrome_opacity <= 0.001

      overlay = chrome_opacity < 0.999 ? @chrome.apply_opacity(@chrome.overlay, chrome_opacity) : @chrome.overlay
      canvas.composite(overlay, :over, x: 0, y: 0)
    end

    def solid(width, height, rgb)
      Vips::Image.black(width, height, bands: 3)
        .new_from_image(rgb)
        .copy(interpretation: :srgb)
    end

    def fit_stage(image)
      max_h = HEIGHT - MIN_TOP_BAR - MIN_BOTTOM_BAR
      scale = [ WIDTH.to_f / image.width, max_h.to_f / image.height ].min
      w = (image.width * scale).round.clamp(1, WIDTH)
      h = (image.height * scale).round.clamp(1, max_h)
      image.thumbnail_image(w, height: h, size: :force)
    end

    def encode(frame_dir, total_frames)
      pattern = frame_dir.join("frame_%05d.jpg").to_s
      cmd = [
        "ffmpeg", "-y",
        "-framerate", @opts[:fps].to_s,
        "-i", pattern,
        "-frames:v", total_frames.to_s,
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-movflags", "+faststart",
        @out_path.to_s
      ]
      stdout, stderr, status = Open3.capture3(*cmd)
      return if status.success?

      raise Error, "ffmpeg failed (#{status.exitstatus}): #{stderr.presence || stdout}"
    end

    def ffmpeg_available?
      _out, _err, status = Open3.capture3("ffmpeg", "-version")
      status.success?
    rescue Errno::ENOENT
      false
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
  end
end
