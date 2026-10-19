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

  test "today shows published edition with AI transparency details" do
    get root_url
    assert_response :success
    assert_match "Published plate", response.body
    assert_match "AI colourised", response.body
    assert_match "Model: #{@model.name}", response.body
    assert_match "Generated", response.body
    assert_match "Reviewed", response.body
    assert_match "Alexander Turnbull Library", response.body
  end

  test "today without edition for today shows unavailable with link to latest" do
    @edition.update!(publish_on: 2.days.ago.to_date)

    get root_url
    assert_response :not_found
    assert_match "Today's edition isn't ready yet", response.body
    assert_match I18n.l(Time.zone.today, format: :long), response.body
    assert_match I18n.l(@edition.publish_on, format: :long), response.body
    assert_match edition_path(@edition), response.body
    assert_no_match "Published plate", response.body
  end

  test "today is edge cached until the next publish without setting a cookie" do
    travel_to Time.zone.today.in_time_zone.change(hour: 8) do
      get root_url
    end

    assert_response :success
    cache_control = response.headers["Cache-Control"]
    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=#{23.hours.to_i}"
    assert_includes cache_control, "stale-if-error=#{1.day.to_i}"
    assert_nil response.headers["Set-Cookie"]
    assert_no_match "csrf-token", response.body
  end

  test "browser max-age never outlives the next publish" do
    travel_to Time.zone.today.in_time_zone.change(hour: 6, min: 58) do
      get edition_url(@edition)
    end

    assert_includes response.headers["Cache-Control"], "max-age=120"
    assert_includes response.headers["Cache-Control"], "s-maxage=120"
  end

  test "today without edition for today is cached briefly" do
    @edition.update!(publish_on: 2.days.ago.to_date)

    get root_url
    assert_response :not_found
    assert_equal "max-age=60, public, s-maxage=60", response.headers["Cache-Control"]
  end

  test "archive lists editions with unbranded composite thumb" do
    attach_fixture_image(@variant, name: :composite_image)
    attach_fixture_image(@variant, name: :share_image)

    get editions_url
    assert_response :success
    assert_match "Published plate", response.body
    assert_includes response.body, @variant.composite_image.blob.signed_id
  end


  test "feed includes edition with stable share image enclosure" do
    attach_fixture_image(@variant, name: :share_image)

    get feed_url
    assert_response :success
    assert_match "Published plate", response.body
    assert_includes response.body, edition_share_image_path(@edition)
  end

  test "scheduled edition show renders not published interstitial" do
    @edition.update!(state: "scheduled", published_at: nil, publish_on: Time.zone.tomorrow)

    get edition_url(@edition)
    assert_response :not_found
    assert_match "Not published yet", response.body
    assert_equal "max-age=60, public, s-maxage=60", response.headers["Cache-Control"]
  end

  test "og image uses stable share image url" do
    attach_fixture_image(@variant, name: :share_image)

    get edition_url(@edition)
    assert_response :success
    og_image = response.body[/property="og:image" content="([^"]+)"/, 1]
    assert_includes og_image, edition_share_image_path(@edition)
  end

  test "show renders adjacent edition navigation" do
    older_source = create_source_item(title: "Older plate")
    older_candidate = older_source.candidates.create!(status: "ready")
    attach_fixture_image(older_candidate)
    older_variant = older_candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(older_variant, name: :colourised_image)
    older = Edition.create!(
      variant: older_variant,
      publish_on: 1.day.ago.to_date,
      state: "published",
      published_at: 1.day.ago
    )

    newer_source = create_source_item(title: "Newer plate")
    newer_candidate = newer_source.candidates.create!(status: "ready")
    attach_fixture_image(newer_candidate)
    newer_variant = newer_candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(newer_variant, name: :colourised_image)
    newer = Edition.create!(
      variant: newer_variant,
      publish_on: Time.zone.tomorrow,
      state: "published",
      published_at: Time.current
    )

    get edition_url(@edition)
    assert_response :success
    assert_match I18n.l(newer.publish_on, format: :long), response.body
    assert_match I18n.l(older.publish_on, format: :long), response.body
    assert_match edition_path(newer), response.body
    assert_match edition_path(older), response.body
  end
end
