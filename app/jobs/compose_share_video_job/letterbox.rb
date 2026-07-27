class ComposeShareVideoJob
  # Computes top/bottom bar heights for a letterboxed landscape plate in 9:16.
  class Letterbox
    Layout = Data.define(:stage_w, :stage_h, :top_bar_h, :bottom_bar_h)

    def initialize(frame_width:, frame_height:, min_top:, min_bottom:)
      @frame_width = frame_width
      @frame_height = frame_height
      @min_top = min_top
      @min_bottom = min_bottom
    end

    def layout_for(stage)
      remainder = @frame_height - stage.height
      if remainder < @min_top + @min_bottom
        raise Renderer::Error, "image too tall for letterboxed short layout"
      end

      top = [ @min_top, (remainder * 0.34).round ].max
      bottom = remainder - top
      if bottom < @min_bottom
        bottom = @min_bottom
        top = remainder - bottom
      end

      Layout.new(
        stage_w: stage.width,
        stage_h: stage.height,
        top_bar_h: top,
        bottom_bar_h: bottom
      )
    end
  end
end
