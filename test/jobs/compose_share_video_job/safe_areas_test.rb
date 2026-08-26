require "test_helper"

class ComposeShareVideoJob
  class SafeAreasTest < ActiveSupport::TestCase
    test "stage max width clears the Reels action rail" do
      assert_equal 968, SafeAreas.stage_max_width
      assert_operator SafeAreas::STAGE_INSET_RIGHT, :>=, 96
    end

    test "minimum bars leave room for platform chrome" do
      assert_operator SafeAreas::PLATFORM_TOP_RESERVE, :>=, 250
      assert_operator SafeAreas::MIN_TOP_BAR, :>=, SafeAreas::PLATFORM_TOP_RESERVE + 120
      assert_operator SafeAreas::MIN_BOTTOM_BAR, :>=, 360
      assert_operator SafeAreas::PLATFORM_BOTTOM_RESERVE, :>=, 120
      assert_operator SafeAreas::PADDING_X, :>=, 56
    end

    test "caption bottom limit sits above platform reserve" do
      assert_equal SafeAreas::FRAME_HEIGHT - SafeAreas::PLATFORM_BOTTOM_RESERVE,
        SafeAreas.caption_bottom_limit
    end
  end

  class LetterboxTest < ActiveSupport::TestCase
    test "layout_for keeps minimum bars and right inset" do
      stage = Data.define(:width, :height).new(width: 968, height: 720)
      layout = Letterbox.new(
        frame_height: SafeAreas::FRAME_HEIGHT,
        min_top: SafeAreas::MIN_TOP_BAR,
        min_bottom: SafeAreas::MIN_BOTTOM_BAR,
        stage_inset_left: SafeAreas::STAGE_INSET_LEFT
      ).layout_for(stage)

      assert_equal 968, layout.stage_w
      assert_equal 720, layout.stage_h
      assert_equal SafeAreas::STAGE_INSET_LEFT, layout.stage_x
      assert_operator layout.top_bar_h, :>=, SafeAreas::MIN_TOP_BAR
      assert_operator layout.bottom_bar_h, :>=, SafeAreas::MIN_BOTTOM_BAR
      assert_equal SafeAreas::FRAME_HEIGHT, layout.top_bar_h + layout.stage_h + layout.bottom_bar_h
    end
  end

  class ChromeTest < ActiveSupport::TestCase
    test "brand and edition sit below the Reels top overlay" do
      overlay = Chrome.new(
        width: SafeAreas::FRAME_WIDTH,
        height: SafeAreas::FRAME_HEIGHT,
        top_bar_h: SafeAreas::MIN_TOP_BAR,
        bottom_bar_h: SafeAreas::MIN_BOTTOM_BAR,
        title: "Title",
        edition_label: "EDITION · JULY 19, 2026",
        meta_rows: []
      ).overlay
      alpha = overlay.extract_band(3)

      reserved = alpha.crop(0, 0, overlay.width, SafeAreas::PLATFORM_TOP_RESERVE)
      assert_equal 0, reserved.max

      left_gutter = alpha.crop(0, SafeAreas::PLATFORM_TOP_RESERVE, SafeAreas::PADDING_X, 120)
      assert_equal 0, left_gutter.max

      brand_band = alpha.crop(
        SafeAreas::PADDING_X,
        SafeAreas::PLATFORM_TOP_RESERVE,
        480,
        120
      )
      assert_operator brand_band.max, :>, 0
    end
  end
end
