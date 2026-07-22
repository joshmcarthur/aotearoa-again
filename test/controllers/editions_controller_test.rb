require "test_helper"

class EditionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/image-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item(title: "Published plate")
    @candidate = @source.candidates.create!(status: "ready")
    attach_fixture_image(@candidate)
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
    @edition = Edition.create!(
      variant: @variant,
      publish_on: Time.zone.today,
      state: "published",
      published_at: Time.current
    )
  end

  test "today shows published edition" do
    get root_url
    assert_response :success
    assert_match "Published plate", response.body
    assert_match "AI colourised", response.body
    assert_match "Alexander Turnbull Library", response.body
  end

  test "archive lists editions" do
    get editions_url
    assert_response :success
    assert_match "Published plate", response.body
  end

  test "feed includes edition" do
    get feed_url
    assert_response :success
    assert_match "Published plate", response.body
  end
end
