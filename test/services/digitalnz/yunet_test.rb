require "test_helper"

module Digitalnz
  class YunetTest < ActiveSupport::TestCase
    test "decodes one face box above the portrait threshold" do
      cols = 4
      rows = 4
      cls = Array.new(rows * cols, 0.0)
      obj = Array.new(rows * cols, 0.0)
      bbox = Array.new(rows * cols * 4, 0.0)
      idx = (1 * cols) + 1
      cls[idx] = 1.0
      obj[idx] = 1.0

      outputs = {
        "cls_8" => cls, "cls_16" => [ 0.0 ], "cls_32" => [ 0.0 ],
        "obj_8" => obj, "obj_16" => [ 0.0 ], "obj_32" => [ 0.0 ],
        "bbox_8" => bbox, "bbox_16" => [ 0.0, 0.0, 0.0, 0.0 ], "bbox_32" => [ 0.0, 0.0, 0.0, 0.0 ]
      }

      fractions = Yunet.new.decode(outputs, 32, 32, 32, 32)

      assert_equal [ 64.0 / 1024 ], fractions
      assert FacePhotographCheck.discard?(fractions)
    end

    test "finds no face in the mono plate fixture" do
      bytes = File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg"))

      assert_equal [], Yunet.new.detect(bytes)
    end
  end
end
