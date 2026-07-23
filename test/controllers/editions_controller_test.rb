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

  test "archive lists editions with unbranded composite thumb" do
    attach_fixture_image(@variant, name: :composite_image)
    attach_fixture_image(@variant, name: :share_image)

    get editions_url
    assert_response :success
    assert_match "Published plate", response.body
    assert_includes response.body, @variant.composite_image.blob.signed_id
  end


  test "feed includes edition" do
    get feed_url
    assert_response :success
    assert_match "Published plate", response.body
  end

  test "scheduled edition show renders not published interstitial" do
    @edition.update!(state: "scheduled", published_at: nil, publish_on: Time.zone.tomorrow)

    get edition_url(@edition)
    assert_response :not_found
    assert_match "Not published yet", response.body
  end

  test "og image prefers share_image when attached" do
    attach_fixture_image(@variant, name: :share_image)

    get edition_url(@edition)
    assert_response :success
    og_image = response.body[/property="og:image" content="([^"]+)"/, 1]
    assert_includes og_image, @variant.share_image.blob.signed_id
  end
end
