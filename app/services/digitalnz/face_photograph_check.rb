module Digitalnz
  class FacePhotographCheck
    # One or two faces, and at least one covers this share of the photo.
    # A seated studio portrait is about 0.013. A rider in a scene is about 0.003.
    MAX_FACE_COUNT = 2
    MIN_FACE_FRACTION = 0.01

    def self.discard?(face_fractions)
      fractions = Array(face_fractions)
      fractions.size.between?(1, MAX_FACE_COUNT) && fractions.max.to_f >= MIN_FACE_FRACTION
    end

    def self.portrait?(io, detector: Yunet.new)
      new(io, detector: detector).portrait?
    end

    def initialize(io, detector:)
      @io = io
      @detector = detector
    end

    def portrait?
      discard?(@detector.detect(read_bytes))
    ensure
      @io.rewind if @io.respond_to?(:rewind)
    end

    private

    def discard?(fractions)
      self.class.discard?(fractions)
    end

    def read_bytes
      bytes = @io.read
      @io.rewind if @io.respond_to?(:rewind)
      bytes
    end
  end
end
