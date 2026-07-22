require "test_helper"

class EditionTest < ActiveSupport::TestCase
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

  test "next_free_publish_on skips occupied dates" do
    tomorrow = Time.zone.tomorrow
    Edition.create!(variant: @variant, publish_on: tomorrow, state: "scheduled")

    other_variant = @candidate.variants.create!(model: @model, prompt: "colourise 2")
    attach_fixture_image(other_variant, name: :colourised_image)
    assert_equal tomorrow + 1.day, Edition.next_free_publish_on
  end

  test "approver schedules edition and deliveries" do
    edition = Editions::Approver.new(@candidate, variant: @variant).call
    assert_equal "scheduled", edition.state
    assert_equal Time.zone.tomorrow, edition.publish_on
    assert_equal %w[email web], edition.deliveries.order(:channel).pluck(:channel)
  end
end
