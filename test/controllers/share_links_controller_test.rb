require "test_helper"

class ShareLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/image-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item(title: "Harbour plate")
    @candidate = @source.candidates.create!(status: "ready")
    attach_fixture_image(@candidate)
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
    @share_link = @variant.create_share_link!
  end

  test "redirects to published edition" do
    edition = Edition.create!(
      variant: @variant,
      publish_on: Time.zone.today,
      state: "published",
      published_at: Time.current
    )

    get share_link_url(@share_link.code)
    assert_redirected_to edition_url(edition)
  end

  test "renders not published interstitial when edition is scheduled" do
    Edition.create!(variant: @variant, publish_on: Time.zone.tomorrow, state: "scheduled")

    get share_link_url(@share_link.code)
    assert_response :not_found
    assert_match "Not published yet", response.body
    assert_match root_path, response.body
  end

  test "renders not published interstitial when variant has no edition" do
    get share_link_url(@share_link.code)
    assert_response :not_found
    assert_match "Not published yet", response.body
  end

  test "unknown code is not found" do
    get share_link_url("does-not-exist")
    assert_response :not_found
  end
end
