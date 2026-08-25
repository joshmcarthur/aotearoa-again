class ComposeShareVideoJob
  # Instagram Reels / Shorts overlay margins for the 9:16 share short.
  # Keeps imagery and on-video captions clear of platform chrome (top nav,
  # right action rail, bottom username / comment bar).
  module SafeAreas
    FRAME_WIDTH = 1080
    FRAME_HEIGHT = 1920

    # Minimum letterbox bars — our brand / NatLib caption plus headroom for IG UI.
    MIN_TOP_BAR = 420
    MIN_BOTTOM_BAR = 380

    # Reels play under the Dynamic Island / status bar; keep brand text below
    # Instagram's top chrome (~14% of 1080×1920).
    PLATFORM_TOP_RESERVE = 270

    # Bottom of frame reserved for IG username, caption peek, and comment field.
    PLATFORM_BOTTOM_RESERVE = 140

    # Reels action icons (like / comment / share) sit on the right rail.
    STAGE_INSET_LEFT = 0
    STAGE_INSET_RIGHT = 112

    PADDING_X = 64
    PADDING_RIGHT = STAGE_INSET_RIGHT + 20

    # Bias slightly more top padding when splitting leftover letterbox space.
    TOP_BAR_FRACTION = 0.38

    module_function

    def stage_max_width
      FRAME_WIDTH - STAGE_INSET_LEFT - STAGE_INSET_RIGHT
    end

    def stage_max_height(min_top: MIN_TOP_BAR, min_bottom: MIN_BOTTOM_BAR)
      FRAME_HEIGHT - min_top - min_bottom
    end

    def caption_bottom_limit(frame_height: FRAME_HEIGHT)
      frame_height - PLATFORM_BOTTOM_RESERVE
    end
  end
end
