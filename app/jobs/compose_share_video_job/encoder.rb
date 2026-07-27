require "open3"

class ComposeShareVideoJob
  # Encodes a directory of JPEG frames to H.264 MP4 via ffmpeg.
  class Encoder
    def initialize(fps:)
      @fps = fps
    end

    def self.available?
      _out, _err, status = Open3.capture3("ffmpeg", "-version")
      status.success?
    rescue Errno::ENOENT
      false
    end

    def encode!(frame_dir:, total_frames:, out_path:)
      pattern = Pathname(frame_dir).join("frame_%05d.jpg").to_s
      cmd = [
        "ffmpeg", "-y",
        "-framerate", @fps.to_s,
        "-i", pattern,
        "-frames:v", total_frames.to_s,
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-movflags", "+faststart",
        out_path.to_s
      ]
      stdout, stderr, status = Open3.capture3(*cmd)
      return if status.success?

      raise Renderer::Error, "ffmpeg failed (#{status.exitstatus}): #{stderr.presence || stdout}"
    end
  end
end
