require "open3"
require "test_helper"

class ComposeShareVideoJob
  class RendererTest < ActiveSupport::TestCase
    COLOUR = [ 40, 180, 90 ].freeze

    test "renders a short mp4 with ffmpeg" do
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")
      skip "fixture missing" unless path.exist?
      skip "ffmpeg not available" unless ffmpeg_available?

      out = Rails.root.join("tmp/test-short-#{SecureRandom.hex(4)}.mp4")
      begin
        result = Renderer.new(
          original_path: path,
          colourised_path: path,
          out_path: out,
          title: "Demo plate title",
          edition_label: "EDITION · JULY 22, 2026",
          meta_rows: [
            MetaRows::Row.new(text: "1 Jan 1900", primary: true),
            MetaRows::Row.new(text: "Alexander Turnbull Library", primary: true),
            MetaRows::Row.new(text: "natlib.govt.nz/records/123 · via DigitalNZ", primary: true),
            MetaRows::Row.new(text: "Attribution 4.0 International (CC BY 4.0)", primary: false),
            MetaRows::Row.new(text: Edition::Copy::AI_NOTICE, primary: false)
          ],
          fps: 10,
          hold_bw_s: 0.1,
          letterbox_s: 0.2,
          wipe_s: 0.2,
          hold_end_s: 0.2
        ).call

        assert_equal out, result
        assert out.exist?
        assert_operator out.size, :>, 1000

        probe = ffprobe_streams(out)
        assert_includes probe, "codec_type=video"
        assert_includes probe, "codec_type=audio"
        assert_includes probe, "codec_name=aac"
      ensure
        out.delete if out.exist?
      end
    end

    test "letterbox backdrop is darkened while the card stays the sharp plate" do
      with_solid_plates do |bw_path, colour_path, dir|
        renderer = Renderer.new(
          original_path: bw_path,
          colourised_path: colour_path,
          out_path: Pathname(dir).join("out.mp4")
        )
        frame = renderer.preview_frame(layout_p: 1.0, wipe_p: 1.0, chrome_opacity: 0.0)
        layout = renderer.instance_variable_get(:@layout)

        top = frame.getpoint(Renderer::WIDTH / 2, 24)
        card = frame.getpoint(
          layout.stage_x + layout.stage_w / 2,
          layout.top_bar_h + layout.stage_h / 2
        )

        assert_in_delta COLOUR[0], card[0], 8
        assert_in_delta COLOUR[1], card[1], 8
        assert_in_delta COLOUR[2], card[2], 8
        top_luma = top.take(3).sum
        card_luma = card.take(3).sum
        assert_operator top_luma, :<, card_luma
        assert_operator top_luma, :>, card_luma * 0.35
      end
    end

    test "letterbox backdrop blurs high-contrast detail" do
      Dir.mktmpdir("aotearoa-blur-") do |dir|
        path = Pathname(dir).join("stripes.png")
        write_stripes(path)
        renderer = Renderer.new(
          original_path: path.to_s,
          colourised_path: path.to_s,
          out_path: Pathname(dir).join("out.mp4")
        )
        frame = renderer.preview_frame(layout_p: 1.0, wipe_p: 1.0, chrome_opacity: 0.0)
        rgb = frame.extract_band(0, n: 3)
        layout = renderer.instance_variable_get(:@layout)
        cy = layout.top_bar_h + (layout.stage_h / 2)

        bg_dev = rgb.crop(0, 24, Renderer::WIDTH, 1).deviate
        card_dev = rgb.crop(layout.stage_x, cy, layout.stage_w, 1).deviate
        assert_operator bg_dev, :<, card_dev
      end
    end

    test "chrome scrim darkens letterbox bars so captions read" do
      with_solid_plates do |bw_path, colour_path, dir|
        renderer = Renderer.new(
          original_path: bw_path,
          colourised_path: colour_path,
          out_path: Pathname(dir).join("out.mp4")
        )
        plain = renderer.preview_frame(layout_p: 1.0, wipe_p: 1.0, chrome_opacity: 0.0)
        scrimmed = renderer.preview_frame(layout_p: 1.0, wipe_p: 1.0, chrome_opacity: 1.0)

        plain_luma = plain.getpoint(Renderer::WIDTH / 2, 24).sum
        scrim_luma = scrimmed.getpoint(Renderer::WIDTH / 2, 24).sum
        assert_operator scrim_luma, :<, plain_luma
      end
    end

    test "letterbox backdrop stays visible under captions" do
      with_solid_plates do |bw_path, colour_path, dir|
        top = Renderer.new(
          original_path: bw_path,
          colourised_path: colour_path,
          out_path: Pathname(dir).join("out.mp4")
        ).preview_frame(layout_p: 1.0, wipe_p: 1.0, chrome_opacity: 1.0)
          .getpoint(Renderer::WIDTH / 2, 24)

        assert_operator top.take(3)[1], :>, 40
      end
    end

    test "letterbox backdrop does not carry the compare wipe" do
      Dir.mktmpdir("aotearoa-backdrop-wipe-") do |dir|
        bw_path = Pathname(dir).join("bw.png")
        colour_path = Pathname(dir).join("colour.png")
        write_solid(bw_path, 0, 0, 0)
        write_solid(colour_path, 255, 255, 255)
        frame = Renderer.new(
          original_path: bw_path.to_s,
          colourised_path: colour_path.to_s,
          out_path: Pathname(dir).join("out.mp4")
        ).preview_frame(layout_p: 1.0, wipe_p: 0.5, chrome_opacity: 0.0)

        left = frame.getpoint(32, 24).take(3).sum
        right = frame.getpoint(Renderer::WIDTH - 32, 24).take(3).sum
        assert_in_delta left, right, 40
      end
    end

    test "right letterbox gutter matches the frosted bars not the wipe" do
      Dir.mktmpdir("aotearoa-gutter-") do |dir|
        bw_path = Pathname(dir).join("bw.png")
        colour_path = Pathname(dir).join("colour.png")
        write_solid(bw_path, 0, 0, 0)
        write_solid(colour_path, 255, 255, 255)
        renderer = Renderer.new(
          original_path: bw_path.to_s,
          colourised_path: colour_path.to_s,
          out_path: Pathname(dir).join("out.mp4")
        )
        frame = renderer.preview_frame(layout_p: 1.0, wipe_p: 0.5, chrome_opacity: 0.0)
        layout = renderer.instance_variable_get(:@layout)
        top = frame.getpoint(Renderer::WIDTH / 2, 24).take(3).sum
        gutter = frame.getpoint(
          Renderer::WIDTH - 32,
          layout.top_bar_h + (layout.stage_h / 2)
        ).take(3).sum

        assert_operator layout.stage_w, :<, Renderer::WIDTH
        assert_in_delta top, gutter, 40
      end
    end

    test "compare handle stays on the card and out of the letterbox bars" do
      Dir.mktmpdir("aotearoa-handle-clip-") do |dir|
        bw_path = Pathname(dir).join("bw.png")
        colour_path = Pathname(dir).join("colour.png")
        write_solid(bw_path, 0, 0, 0)
        write_solid(colour_path, 255, 255, 255)
        renderer = Renderer.new(
          original_path: bw_path.to_s,
          colourised_path: colour_path.to_s,
          out_path: Pathname(dir).join("out.mp4")
        )
        frame = renderer.preview_frame(layout_p: 1.0, wipe_p: 0.5, chrome_opacity: 0.0)
        layout = renderer.instance_variable_get(:@layout)
        x = layout.stage_x + (layout.stage_w / 2)
        above = frame.getpoint(x, layout.top_bar_h - 4).take(3).sum
        on_card = frame.getpoint(x, layout.top_bar_h + 8).take(3).sum

        assert_operator on_card, :>, 600
        assert_operator above, :<, 400
      end
    end

    test "compare handle sits on the letterboxed plate during the wipe" do
      Dir.mktmpdir("aotearoa-handle-") do |dir|
        bw_path = Pathname(dir).join("bw.png")
        colour_path = Pathname(dir).join("colour.png")
        write_solid(bw_path, 0, 0, 0)
        write_solid(colour_path, 255, 255, 255)
        renderer = Renderer.new(
          original_path: bw_path.to_s,
          colourised_path: colour_path.to_s,
          out_path: Pathname(dir).join("out.mp4")
        )
        frame = renderer.preview_frame(layout_p: 1.0, wipe_p: 0.5, chrome_opacity: 0.0)
        layout = renderer.instance_variable_get(:@layout)
        knob = frame.getpoint(
          layout.stage_x + layout.stage_w / 2,
          layout.top_bar_h + layout.stage_h / 2
        )
        fill = ComposeShareImageJob::CompareHandle::KNOB_FILL
        assert_in_delta fill[0], knob[0], 12
        assert_in_delta fill[1], knob[1], 12
        assert_in_delta fill[2], knob[2], 12
      end
    end

    private

    def with_solid_plates
      Dir.mktmpdir("aotearoa-frame-") do |dir|
        bw_path = Pathname(dir).join("bw.png")
        colour_path = Pathname(dir).join("colour.png")
        write_solid(bw_path, 10, 10, 10)
        write_solid(colour_path, *COLOUR)
        yield bw_path.to_s, colour_path.to_s, dir
      end
    end

    def write_solid(path, r, g, b)
      Vips::Image.black(200, 100, bands: 3)
        .new_from_image([ r, g, b ])
        .copy(interpretation: :srgb)
        .pngsave(path.to_s)
    end

    def write_stripes(path)
      stripe_w = 20
      height = Renderer::HEIGHT
      tiles = (Renderer::WIDTH / stripe_w).times.map do |i|
        rgb = i.even? ? [ 255, 255, 255 ] : [ 0, 0, 0 ]
        Vips::Image.black(stripe_w, height, bands: 3)
          .new_from_image(rgb)
          .copy(interpretation: :srgb)
      end
      tiles.reduce { |left, right| left.join(right, :horizontal) }.pngsave(path.to_s)
    end

    def ffmpeg_available?
      _out, _err, status = Open3.capture3("ffmpeg", "-version")
      status.success?
    rescue Errno::ENOENT
      false
    end

    def ffprobe_streams(path)
      out, _err, status = Open3.capture3(
        "ffprobe", "-v", "error",
        "-show_entries", "stream=codec_type,codec_name",
        "-of", "default=noprint_wrappers=0",
        path.to_s
      )
      assert status.success?, "ffprobe failed for #{path}"
      out
    end
  end
end
