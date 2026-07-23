require "test_helper"

class VariantTest < ActiveSupport::TestCase
  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/image-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item
    @candidate = @source.candidates.create!(status: "ready")
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
  end

  test "distribution_image prefers share_image" do
    attach_fixture_image(@variant, name: :colourised_image)
    assert_equal @variant.colourised_image.blob_id, @variant.distribution_image.blob_id

    attach_fixture_image(@variant, name: :share_image)
    assert_equal @variant.share_image.blob_id, @variant.distribution_image.blob_id
  end
end
