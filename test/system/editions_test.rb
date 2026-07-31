require "application_system_test_case"

class EditionsTest < ApplicationSystemTestCase
  test "today page loads when no edition is published" do
    visit root_path

    assert_text "Next plate soon"
    assert_text "Aotearoa, Again"
  end

  test "today shows a published edition" do
    create_published_edition!

    visit root_path

    assert_text "Published plate"
    assert_text "A photograph of the waterfront."
    assert_text "Wellington"
  end

  test "archive lists published editions" do
    create_published_edition!

    visit editions_path

    assert_text "Archive"
    assert_text "Published plate"
    assert_text(/#{Regexp.escape(I18n.l(Time.zone.today, format: :long))}/i)
  end

  test "edition show page renders plate details" do
    edition = create_published_edition!

    visit edition_path(edition)

    assert_text "Published plate"
    assert_text "Plate details"
    assert_text "Alexander Turnbull Library"
  end

  private

  def create_published_edition!
    model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/image-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    source = create_source_item(title: "Published plate")
    candidate = source.candidates.create!(status: "ready")
    attach_fixture_image(candidate)
    variant = candidate.variants.create!(model: model, prompt: "colourise", chosen: true)
    attach_fixture_image(variant, name: :colourised_image)
    Edition.create!(
      variant: variant,
      publish_on: Time.zone.today,
      state: "published",
      published_at: Time.current
    )
  end
end
