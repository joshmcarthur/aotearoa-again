require "test_helper"

class CandidateTest < ActiveSupport::TestCase
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
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
  end

  test "ready_or_in_pipeline includes ready candidates without editions" do
    assert_includes Candidate.ready_or_in_pipeline, @candidate
  end

  test "ready_or_in_pipeline excludes ready candidates with scheduled editions" do
    Edition.create!(variant: @variant, publish_on: Time.zone.tomorrow, state: "scheduled")

    assert_not_includes Candidate.ready_or_in_pipeline, @candidate
  end

  test "ready_or_in_pipeline excludes ready candidates with published editions" do
    Edition.create!(
      variant: @variant,
      publish_on: 1.day.ago.to_date,
      state: "published",
      published_at: 1.day.ago
    )

    assert_not_includes Candidate.ready_or_in_pipeline, @candidate
  end

  test "ready_or_in_pipeline includes pending_colour candidates" do
    pending = @source.candidates.create!(status: "pending_colour")

    assert_includes Candidate.ready_or_in_pipeline, pending
  end

  test "awaiting_approval includes ready candidates without editions" do
    assert_includes Candidate.awaiting_approval, @candidate
  end

  test "awaiting_approval excludes ready candidates with editions" do
    Edition.create!(variant: @variant, publish_on: Time.zone.tomorrow, state: "scheduled")

    assert_not_includes Candidate.awaiting_approval, @candidate
  end
end
