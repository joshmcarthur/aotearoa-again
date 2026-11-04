require "onnxruntime"
require "vips"

module Digitalnz
  # OpenCV Zoo YuNet, MIT. Boxes are decoded the same way as OpenCV FaceDetectorYN.
  class Yunet
    MODEL_PATH = Rails.root.join("vendor/models/face_detection_yunet_2023mar.onnx")
    INPUT_SIZE = 640
    SCORE_THRESHOLD = 0.6
    NMS_THRESHOLD = 0.3
    STRIDES = [ 8, 16, 32 ].freeze

    def self.model
      @model ||= OnnxRuntime::Model.new(MODEL_PATH.to_s)
    end

    def detect(bytes)
      prepared = prepare(bytes)
      outputs = self.class.model.predict({ "input" => [ nchw(prepared.image) ] })
      decode(outputs, prepared.image.width, prepared.image.height, prepared.content_width, prepared.content_height)
    end

    def decode(outputs, pad_width, pad_height, content_width, content_height)
      area = content_width.to_f * content_height.to_f
      return [] if area <= 0

      faces = []
      STRIDES.each_with_index do |stride, index|
        cols = pad_width / stride
        rows = pad_height / stride
        cls = flatten(outputs["cls_#{stride}"] || outputs.values[index])
        obj = flatten(outputs["obj_#{stride}"] || outputs.values[index + STRIDES.size])
        bbox = flatten(outputs["bbox_#{stride}"] || outputs.values[index + (STRIDES.size * 2)])

        rows.times do |row|
          cols.times do |col|
            idx = (row * cols) + col
            score = Math.sqrt(clamp(cls[idx]) * clamp(obj[idx]))
            next if score < SCORE_THRESHOLD

            cx = (col + bbox[(idx * 4) + 0]) * stride
            cy = (row + bbox[(idx * 4) + 1]) * stride
            width = Math.exp(bbox[(idx * 4) + 2]) * stride
            height = Math.exp(bbox[(idx * 4) + 3]) * stride
            faces << { x: cx - (width / 2.0), y: cy - (height / 2.0), w: width, h: height, score: score }
          end
        end
      end

      nms(faces).map { |face| (face[:w] * face[:h]) / area }
    end

    private

    def prepare(bytes)
      image = Vips::Image.new_from_buffer(bytes, "")
      image = image.flatten if image.has_alpha?
      image = image.colourspace(:srgb) unless image.interpretation == :srgb
      image = image.bandjoin([ image, image ]) if image.bands == 1
      image = image.extract_band(0, n: 3) if image.bands > 3

      scale = INPUT_SIZE.to_f / [ image.width, image.height ].max
      image = image.resize(scale)
      content_width = image.width
      content_height = image.height
      Prepared.new(
        image: image.embed(0, 0, INPUT_SIZE, INPUT_SIZE, extend: :black),
        content_width: content_width,
        content_height: content_height
      )
    end

    Prepared = Struct.new(:image, :content_width, :content_height, keyword_init: true)

    def nchw(image)
      bgr = image[2].bandjoin([ image[1], image[0] ])
      bytes = bgr.write_to_memory.unpack("C*")
      width = bgr.width
      height = bgr.height

      Array.new(3) do |band|
        Array.new(height) do |row|
          Array.new(width) do |col|
            bytes[((((row * width) + col) * 3) + band)].to_f
          end
        end
      end
    end

    def flatten(value)
      case value
      when Array
        value.flatten
      else
        Array(value)
      end
    end

    def clamp(value)
      value.to_f.clamp(0.0, 1.0)
    end

    def nms(faces)
      kept = []
      faces.sort_by { |face| -face[:score] }.each do |face|
        next if kept.any? { |other| iou(face, other) > NMS_THRESHOLD }

        kept << face
      end
      kept
    end

    def iou(left, right)
      x1 = [ left[:x], right[:x] ].max
      y1 = [ left[:y], right[:y] ].max
      x2 = [ left[:x] + left[:w], right[:x] + right[:w] ].min
      y2 = [ left[:y] + left[:h], right[:y] + right[:h] ].min
      intersection = [ x2 - x1, 0 ].max * [ y2 - y1, 0 ].max
      union = (left[:w] * left[:h]) + (right[:w] * right[:h]) - intersection
      return 0.0 if union <= 0

      intersection / union
    end
  end
end
