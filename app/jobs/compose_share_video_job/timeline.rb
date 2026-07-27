class ComposeShareVideoJob
  # Samples layout progress, wipe center, and caption opacity over the short.
  module Timeline
    module_function

    def sample_at(time, t_hold_start_end:, t_motion_end:, t_caption_start:, caption_fade_s:, center_bw:, center_colour:)
      layout_p, wipe_p =
        if time < t_hold_start_end
          [ 0.0, center_bw ]
        elsif time < t_motion_end
          raw = (time - t_hold_start_end) / (t_motion_end - t_hold_start_end)
          [
            ease_out_cubic(raw),
            lerp(center_bw, center_colour, smoothstep([ raw * 1.15, 1.0 ].min))
          ]
        else
          [ 1.0, center_colour ]
        end

      chrome =
        if time < t_caption_start || caption_fade_s <= 0
          time < t_caption_start ? 0.0 : 1.0
        else
          ease_out_cubic(((time - t_caption_start) / caption_fade_s).clamp(0.0, 1.0))
        end

      [ layout_p, wipe_p, chrome ]
    end

    def smoothstep(t)
      t = t.clamp(0.0, 1.0)
      t * t * (3.0 - 2.0 * t)
    end

    def ease_out_cubic(t)
      t = t.clamp(0.0, 1.0)
      1.0 - (1.0 - t)**3
    end

    def lerp(a, b, t)
      a + (b - a) * t
    end
  end
end
