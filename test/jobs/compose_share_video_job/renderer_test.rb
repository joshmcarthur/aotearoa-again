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
  end
end
