require "test_helper"

class ComposeShareVideoJob
  class TimelineTest < ActiveSupport::TestCase
    setup do
      @opts = {
        hold_bw_s: 1.0,
        letterbox_s: 1.0,
        wipe_s: 2.0,
        hold_end_s: 4.0,
        caption_fade_s: 0.5,
        caption_lead_s: 0.5
      }
      @schedule = Timeline.schedule_for(@opts)
    end

    test "schedule totals all phases" do
      assert_in_delta 8.0, @schedule.end, 0.001
      assert_in_delta 1.0, @schedule.hold_bw_end, 0.001
      assert_in_delta 2.0, @schedule.letterbox_end, 0.001
      assert_in_delta 4.0, @schedule.wipe_end, 0.001
      assert_in_delta 1.5, @schedule.caption_start, 0.001
    end

    test "letterbox and captions start before the wipe" do
      layout, wipe, chrome = Timeline.sample_at(1.7, @schedule)
      assert_operator layout, :>, 0.0
      assert_operator layout, :<, 1.0
      assert_in_delta 0.0, wipe, 0.001
      assert_operator chrome, :>, 0.0
    end

    test "letterbox zoom eases in and out instead of running linear" do
      letterbox = @schedule.letterbox_end - @schedule.hold_bw_end
      early_t = @schedule.hold_bw_end + (letterbox * 0.25)
      late_t = @schedule.hold_bw_end + (letterbox * 0.75)
      early, = Timeline.sample_at(early_t, @schedule)
      late, = Timeline.sample_at(late_t, @schedule)

      assert_operator early, :<, 0.25
      assert_operator late, :>, 0.75
    end

    test "wipe sweeps while letterboxed with metadata showing" do
      layout, wipe, chrome = Timeline.sample_at(3.0, @schedule)
      assert_in_delta 1.0, layout, 0.001
      assert_operator wipe, :>, 0.0
      assert_operator wipe, :<, 1.0
      assert_in_delta 1.0, chrome, 0.001
    end

    test "end hold stays letterboxed in colour with captions" do
      layout, wipe, chrome = Timeline.sample_at(6.0, @schedule)
      assert_in_delta 1.0, layout, 0.001
      assert_in_delta 1.0, wipe, 0.001
      assert_in_delta 1.0, chrome, 0.001
    end
  end
end
