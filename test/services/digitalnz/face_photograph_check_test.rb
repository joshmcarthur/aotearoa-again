require "test_helper"

module Digitalnz
  class FacePhotographCheckTest < ActiveSupport::TestCase
    test "discards one large face" do
      assert FacePhotographCheck.discard?([ 0.2 ])
    end

    test "discards a seated portrait face" do
      assert FacePhotographCheck.discard?([ 0.013 ])
    end

    test "discards two large faces" do
      assert FacePhotographCheck.discard?([ 0.12, 0.08 ])
    end

    test "keeps three or more faces" do
      assert_not FacePhotographCheck.discard?([ 0.2, 0.1, 0.08 ])
    end

    test "keeps a small face" do
      assert_not FacePhotographCheck.discard?([ 0.003 ])
    end

    test "keeps a photo with no faces" do
      assert_not FacePhotographCheck.discard?([])
    end

    test "uses the detector on the image" do
      detector = Object.new
      detector.define_singleton_method(:detect) { |_bytes| [ 0.2 ] }
      io = StringIO.new("image-bytes")

      assert FacePhotographCheck.portrait?(io, detector: detector)
      assert_equal 0, io.pos
    end
  end
end
