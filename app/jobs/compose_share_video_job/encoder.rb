require "open3"

class ComposeShareVideoJob
  # Encodes a directory of JPEG frames to H.264 MP4 via ffmpeg, muxing the share sting.
  class Encoder
    AUDIO_PATH = Rails.root.join("app/assets/audio/short-sting.ogg")

    def initialize(fps:, audio_path: AUDIO_PATH)
      @fps = fps
      @audio_path = Pathname(audio_path)
    end

    def self.available?
      _out, _err, status = Open3.capture3("ffmpeg", "-version")
      status.success?
    rescue Errno::ENOENT
      false
    end

    def encode!(frame_dir:, total_frames:, out_path:)
      raise Renderer::Error, "share audio missing: #{@audio_path}" unless @audio_path.exist?

      pattern = Pathname(frame_dir).join("frame_%05d.jpg").to_s
      cmd = [
        "ffmpeg", "-y",
        "-framerate", @fps.to_s,
        "-i", pattern,
        "-i", @audio_path.to_s,
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-frames:v", total_frames.to_s,
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-c:a", "aac",
        "-b:a", "160k",
        "-ac", "2",
        "-ar", "48000",
        "-shortest",
        "-movflags", "+faststart",
        out_path.to_s
      ]
      stdout, stderr, status = Open3.capture3(*cmd)
      return if status.success?

      raise Renderer::Error, "ffmpeg failed (#{status.exitstatus}): #{stderr.presence || stdout}"
    end
  end
end
