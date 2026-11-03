require "vips"

module Digitalnz
  class ColourPhotographCheck
    THUMBNAIL_SIZE = 128
    MIN_CHROMA = 12.0
    COOL_AXIS = 8.0
    MAX_COOL_FRACTION = 0.05

    def self.colour_photograph?(io)
      new(io).colour_photograph?
    end

    def initialize(io)
      @io = io
    end

    def colour_photograph?
      image = Vips::Image.new_from_buffer(read_bytes, "")
      return false if image.bands < 3

      lab = image.thumbnail_image(THUMBNAIL_SIZE).colourspace(:lab)
      a_band = lab[1]
      b_band = lab[2]
      chroma = ((a_band**2) + (b_band**2))**0.5
      chromatic = chroma > MIN_CHROMA
      cool = chromatic & ((a_band < -COOL_AXIS) | (b_band < -COOL_AXIS))
      cool.avg / 255.0 >= MAX_COOL_FRACTION
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
