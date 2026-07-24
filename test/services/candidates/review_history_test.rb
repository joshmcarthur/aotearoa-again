require "test_helper"

module Candidates
  class ReviewHistoryTest < ActiveSupport::TestCase
    setup do
      @model = Model.openrouter.image_capable.first || Model.create!(
        model_id: "test/image-model",
        name: "Test Image",
        provider: "openrouter",
        modalities: { "input" => [ "image" ], "output" => [ "image" ] }
      )
      @source = create_source_item
      @candidate = @source.candidates.create!(status: "ready")
      attach_fixture_image(@candidate)
    end

    test "needs_review when ready with variants but no edition" do
      @candidate.variants.create!(model: @model, prompt: "colourise")
      history = ReviewHistory.new(@candidate)

      assert_equal :needs_review, history.status
      assert_equal "Needs review", history.status_label
      assert_includes history.summary, "1 variant"
      assert_includes history.summary, "not reviewed"
    end

    test "scheduled when edition is scheduled" do
      variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(variant, name: :colourised_image)
      edition = Edition.create!(variant: variant, publish_on: Time.zone.tomorrow, state: "scheduled")

      history = ReviewHistory.new(@candidate)

      assert_equal :scheduled, history.status
      assert_includes history.summary, edition.publish_on.to_s
      assert history.events.any? { |event| event.kind == :approved }
    end

    test "published when edition has published" do
      variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(variant, name: :colourised_image)
      Edition.create!(
        variant: variant,
        publish_on: 1.day.ago.to_date,
        state: "published",
        published_at: 1.day.ago
      )

      history = ReviewHistory.new(@candidate)

      assert_equal :published, history.status
      assert history.events.any? { |event| event.kind == :published }
    end

    test "failed when edition publish failed" do
      variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(variant, name: :colourised_image)
      Edition.create!(
        variant: variant,
        publish_on: Time.zone.tomorrow,
        state: "failed",
        admin_note: "Buttondown error"
      )

      history = ReviewHistory.new(@candidate)

      assert_equal :failed, history.status
      failed_event = history.events.find { |event| event.kind == :failed }
      assert_equal "Buttondown error", failed_event.detail
    end

    test "rejected when candidate is rejected" do
      @candidate.reject!(reason: "Not suitable")

      history = ReviewHistory.new(@candidate)

      assert_equal :rejected, history.status
      rejected_event = history.events.find { |event| event.kind == :rejected }
      assert_equal "Not suitable", rejected_event.detail
    end

    test "events are ordered chronologically" do
      travel_to 3.days.ago do
        @candidate.variants.create!(model: @model, prompt: "first")
      end

      travel_to 1.day.ago do
        @candidate.variants.create!(model: @model, prompt: "second", chosen: true)
      end

      history = ReviewHistory.new(@candidate)
      timestamps = history.events.map(&:at)

      assert_equal timestamps.sort, timestamps
      assert_equal 3, history.events.size
    end
  end
end
