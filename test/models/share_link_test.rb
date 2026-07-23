require "test_helper"

class ShareLinkTest < ActiveSupport::TestCase
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

  test "assigns unique code and builds absolute url" do
    link = @variant.create_share_link!

    assert link.code.present?
    assert_equal "/s/#{link.code}", link.path
    assert_includes link.url, "/s/#{link.code}"
  end
end
