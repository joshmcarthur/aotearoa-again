class ComposeShareVideoJob
  # Computes top/bottom bar heights for a letterboxed landscape plate in 9:16.
  class Letterbox
    Layout = Data.define(:stage_w, :stage_h, :stage_x, :top_bar_h, :bottom_bar_h)

    def initialize(frame_height:, min_top:, min_bottom:, stage_inset_left: 0)
      @frame_height = frame_height
      @min_top = min_top
      @min_bottom = min_bottom
      @stage_inset_left = stage_inset_left
    end

    def layout_for(stage)
      remainder = @frame_height - stage.height
      if remainder < @min_top + @min_bottom
        raise Renderer::Error, "image too tall for letterboxed short layout"
      end

      top = [ @min_top, (remainder * SafeAreas::TOP_BAR_FRACTION).round ].max
      bottom = remainder - top
      if bottom < @min_bottom
        bottom = @min_bottom
        top = remainder - bottom
      end

      Layout.new(
        stage_w: stage.width,
        stage_h: stage.height,
        stage_x: @stage_inset_left,
        top_bar_h: top,
        bottom_bar_h: bottom
      )
    end
  end
end
