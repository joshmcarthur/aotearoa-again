require "test_helper"

class EditionImagesControllerTest < ActionDispatch::IntegrationTest
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

  test "share image serves branded jpeg for published editions" do
    attach_fixture_image(@variant, name: :share_image)

    get edition_share_image_url(@edition)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert response.body.bytesize.positive?
  end

  test "share image serves scheduled editions for publish-time delivery" do
    attach_fixture_image(@variant, name: :share_image)
    @edition.update!(state: "scheduled", published_at: nil)

    get edition_share_image_url(@edition)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "share image is not found for failed editions" do
    attach_fixture_image(@variant, name: :share_image)
    @edition.update!(state: "failed", published_at: nil)

    get edition_share_image_url(@edition)
    assert_response :not_found
  end

  test "composite image serves unbranded jpeg for published editions" do
    attach_fixture_image(@variant, name: :composite_image)

    get edition_composite_image_url(@edition)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert response.body.bytesize.positive?
  end

  test "composite image serves scheduled editions" do
    attach_fixture_image(@variant, name: :composite_image)
    @edition.update!(state: "scheduled", published_at: nil)

    get edition_composite_image_url(@edition)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "composite image is not found for failed editions" do
    attach_fixture_image(@variant, name: :composite_image)
    @edition.update!(state: "failed", published_at: nil)

    get edition_composite_image_url(@edition)
    assert_response :not_found
  end

  test "share image is served to Gmail image proxy user agent" do
    attach_fixture_image(@variant, name: :share_image)

    get edition_share_image_url(@edition),
      headers: {
        "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 5.1; rv:11.0) Gecko Firefox/11.0 (via ggpht.com GoogleImageProxy)"
      }

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "composite image is served to Gmail image proxy user agent" do
    attach_fixture_image(@variant, name: :composite_image)

    get edition_composite_image_url(@edition),
      headers: {
        "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 5.1; rv:11.0) Gecko Firefox/11.0 (via ggpht.com GoogleImageProxy)"
      }

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end
end
