class ComposeShareVideoJob
  # Samples layout progress, compare-wipe position, and caption opacity over the short.
  class Timeline
    Schedule = Data.define(
      :hold_bw_end,
      :wipe_end,
      :hold_colour_end,
      :letterbox_end,
      :end,
      :caption_start,
      :caption_fade_s
    )

    class << self
      def schedule_for(opts)
        hold_bw = opts.fetch(:hold_bw_s).to_f
        wipe = opts.fetch(:wipe_s).to_f
        hold_colour = opts.fetch(:hold_colour_s).to_f
        letterbox = opts.fetch(:letterbox_s).to_f
        hold_end = opts.fetch(:hold_end_s).to_f
        caption_fade = opts.fetch(:caption_fade_s).to_f
        caption_lead = opts.fetch(:caption_lead_s).to_f

        hold_bw_end = hold_bw
        wipe_end = hold_bw_end + wipe
        hold_colour_end = wipe_end + hold_colour
        letterbox_end = hold_colour_end + letterbox
        end_at = letterbox_end + hold_end
        caption_start = [ letterbox_end - caption_lead, wipe_end ].max

        Schedule.new(
          hold_bw_end:,
          wipe_end:,
          hold_colour_end:,
          letterbox_end:,
          end: end_at,
          caption_start:,
          caption_fade_s: caption_fade
        )
      end

      def sample_at(time, schedule)
        layout_p, wipe_p =
          if time < schedule.hold_bw_end
            [ 0.0, 0.0 ]
          elsif time < schedule.wipe_end
            raw = (time - schedule.hold_bw_end) / (schedule.wipe_end - schedule.hold_bw_end)
            [ 0.0, smoothstep(raw) ]
          elsif time < schedule.hold_colour_end
            [ 0.0, 1.0 ]
          elsif time < schedule.letterbox_end
            raw = (time - schedule.hold_colour_end) / (schedule.letterbox_end - schedule.hold_colour_end)
            [ ease_out_cubic(raw), 1.0 ]
          else
            [ 1.0, 1.0 ]
          end

        chrome =
          if time < schedule.caption_start || schedule.caption_fade_s <= 0
            time < schedule.caption_start ? 0.0 : 1.0
          else
            ease_out_cubic(((time - schedule.caption_start) / schedule.caption_fade_s).clamp(0.0, 1.0))
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
end
