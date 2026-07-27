require "vips"

ENV["PANGOCAIRO_BACKEND"] ||= "fontconfig"

class ComposeShareVideoJob
  # Renders Fraunces / Source Sans text layers for short chrome.
  class TextPainter
    TEXT_RGB = [ 243, 239, 230 ].freeze

    DISPLAY_FONT_PATH = ComposeShareImageJob::BrandChip::FONT_PATH
    DISPLAY_FONT_NAME = "Fraunces Bold"
    BODY_FONT_PATH = Rails.root.join("app/assets/fonts/SourceSans3-Regular.ttf")
    BODY_FONT_NAME = "Source Sans 3"

    def self.paint(string, width:, font_height:, height: nil, rgb: TEXT_RGB, style: :display, spacing: nil)
      new.paint(string, width:, font_height:, height:, rgb:, style:, spacing:)
    end

    def paint(string, width:, font_height:, height: nil, rgb: TEXT_RGB, style: :display, spacing: nil)
      font_name, font_path = font_for(style)
      opts = {
        font: "#{font_name} #{font_height}",
        fontfile: font_path.to_s,
        width: width,
        rgba: true,
        align: :low
      }
      # Avoid tight height autofit — it scales glyphs to fill the box and kills line-height.
      opts[:height] = height if height
      opts[:spacing] = spacing if spacing

      text = Vips::Image.text(string.to_s, **opts)
      alpha = text.extract_band(3)
      text
        .new_from_image(rgb)
        .copy(interpretation: :srgb)
        .bandjoin(alpha)
    end

    private

    def font_for(style)
      case style
      when :display then [ DISPLAY_FONT_NAME, DISPLAY_FONT_PATH ]
      when :body then [ BODY_FONT_NAME, BODY_FONT_PATH ]
      else
        raise ArgumentError, "unknown text style: #{style.inspect}"
      end
    end
  end
end
