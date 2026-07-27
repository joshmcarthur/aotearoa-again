require "open3"
require "test_helper"

class ComposeShareVideoJob
  class RendererTest < ActiveSupport::TestCase
    setup do
      @path = Rails.root.join("test/fixtures/files/mono_plate.jpg")
      skip "fixture missing" unless @path.exist?
    end

    test "renders a short mp4 with ffmpeg" do
      skip "ffmpeg not available" unless ffmpeg_available?

      out = Rails.root.join("tmp/test-short-#{SecureRandom.hex(4)}.mp4")
      begin
        result = Renderer.new(
          original_path: @path,
          colourised_path: @path,
          out_path: out,
          title: "Demo plate title",
          edition_label: "EDITION · JULY 22, 2026",
          meta_rows: [
            MetaRows::Row.new(text: "1 Jan 1900", primary: true),
            MetaRows::Row.new(text: "Alexander Turnbull Library", primary: true),
            MetaRows::Row.new(text: "natlib.govt.nz/records/123 · via DigitalNZ", primary: true),
            MetaRows::Row.new(text: "Attribution 4.0 International (CC BY 4.0)", primary: false),
            MetaRows::Row.new(text: Editions::Copy::AI_NOTICE, primary: false)
          ],
          fps: 10,
          hold_start_s: 0.2,
          motion_s: 0.4,
          hold_end_s: 0.3
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

    private

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
