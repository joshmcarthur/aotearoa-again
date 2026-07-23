require "test_helper"

class ComposeShareImageJobTest < ActiveJob::TestCase
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

  test "creates share link and attaches share image" do
    ComposeShareImageJob.perform_now(@variant.id)

    @variant.reload
    assert @variant.share_link.present?
    assert @variant.share_image.attached?
    assert_equal "image/jpeg", @variant.share_image.content_type
  end
end
