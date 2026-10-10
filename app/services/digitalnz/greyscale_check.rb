require "vips"

module Digitalnz
  class GreyscaleCheck
    # Mean per-channel absolute deviation. Silvering and warm scans stay under this;
    # saturated colour photographs do not.
    MAX_MEAN_CHROMA = 12.0

    def self.greyscale?(io)
      new(io).greyscale?
    end

    def initialize(io)
      @io = io
    end

    def greyscale?
      image = Vips::Image.new_from_buffer(read_bytes, "")
      return true if image.bands < 3

      red = image.extract_band(0)
      green = image.extract_band(1)
      blue = image.extract_band(2)
      chroma = ((red - green).abs + (green - blue).abs + (blue - red).abs).avg / 3.0
      chroma < MAX_MEAN_CHROMA
    ensure
      @io.rewind if @io.respond_to?(:rewind)
    end

    private

    def read_bytes
      bytes = @io.read
      @io.rewind if @io.respond_to?(:rewind)
      bytes
    end
  end
end
