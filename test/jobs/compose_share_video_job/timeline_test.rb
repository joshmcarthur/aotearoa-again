require "test_helper"

class ComposeShareVideoJob
  class TimelineTest < ActiveSupport::TestCase
    setup do
      @opts = {
        hold_bw_s: 1.0,
        wipe_s: 2.0,
        hold_colour_s: 2.0,
        letterbox_s: 1.0,
        hold_end_s: 2.0,
        caption_fade_s: 0.5,
        caption_lead_s: 0.5
      }
      @schedule = Timeline.schedule_for(@opts)
    end

    test "schedule totals all phases" do
      assert_in_delta 8.0, @schedule.end, 0.001
      assert_in_delta 1.0, @schedule.hold_bw_end, 0.001
      assert_in_delta 3.0, @schedule.wipe_end, 0.001
      assert_in_delta 5.0, @schedule.hold_colour_end, 0.001
      assert_in_delta 6.0, @schedule.letterbox_end, 0.001
    end

    test "wipe runs at full bleed before letterbox" do
      layout, wipe, chrome = Timeline.sample_at(2.5, @schedule)
      assert_in_delta 0.0, layout, 0.001
      assert_operator wipe, :>, 0.0
      assert_operator wipe, :<, 1.0
      assert_in_delta 0.0, chrome, 0.001
    end

    test "colour hold stays full bleed" do
      layout, wipe, chrome = Timeline.sample_at(4.0, @schedule)
      assert_in_delta 0.0, layout, 0.001
      assert_in_delta 1.0, wipe, 0.001
      assert_in_delta 0.0, chrome, 0.001
    end

    test "letterbox follows colour hold" do
      layout, wipe, _chrome = Timeline.sample_at(5.5, @schedule)
      assert_operator layout, :>, 0.0
      assert_operator layout, :<, 1.0
      assert_in_delta 1.0, wipe, 0.001
    end

    test "captions fade in during letterbox" do
      _layout, _wipe, chrome = Timeline.sample_at(5.75, @schedule)
      assert_operator chrome, :>, 0.0
      assert_operator chrome, :<, 1.0
    end
  end
end
