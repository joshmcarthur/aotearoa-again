require "test_helper"

class Edition
  class CopyTest < ActiveSupport::TestCase
    setup do
      @model = Model.openrouter.image_capable.first || Model.create!(
        model_id: "test/copy-image-model",
        name: "Test Image",
        provider: "openrouter",
        modalities: { "input" => [ "image" ], "output" => [ "image" ] }
      )
      @source = create_source_item
      @candidate = @source.candidates.create!(status: "ready")
      attach_fixture_image(@candidate)
      @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(@variant, name: :colourised_image)
      @edition = Edition.create!(variant: @variant, publish_on: Date.new(2026, 7, 25), state: "scheduled")
    end

    test "uses description as caption and builds attribution from metadata" do
      copy = @edition.copy

      assert_equal @source.title, copy.title
      assert_equal @source.description, copy.caption
      assert_includes copy.attribution_text, "Alexander Turnbull Library"
      assert_includes copy.attribution_text, @source.record_url
      assert_includes copy.attribution_text, "DigitalNZ"
      assert_includes copy.ai_notice, Copy::AI_NOTICE
    end

    test "ai_notice includes model generation and review dates" do
      @model.update!(name: "Gemini Flash")
      @variant.update!(created_at: Time.zone.local(2026, 7, 10, 14, 30))
      @edition.update!(created_at: Time.zone.local(2026, 7, 12, 9, 0))

      notice = @edition.copy.ai_notice

      assert_includes notice, Copy::AI_NOTICE
      assert_includes notice, "Model: Gemini Flash."
      assert_includes notice, "Generated #{I18n.l(Date.new(2026, 7, 10), format: :long)}."
      assert_includes notice, "Reviewed #{I18n.l(Date.new(2026, 7, 12), format: :long)}."
    end

    test "falls back when description blank" do
      @source.update!(description: nil, display_date: "1901", placename: "Dunedin")
      copy = @edition.copy
      assert_includes copy.caption, "1901"
      assert_includes copy.caption, "Dunedin"
    end

    test "email instagram and facebook share the same narrative body" do
      copy = @edition.copy
      edition_url = @edition.public_url
      body = copy.body_text

      assert_includes body, @source.description
      assert_includes body, "Alexander Turnbull Library"
      assert_includes body, @source.record_url

      email = copy.email_markdown(image_url: "https://example.com/composite.jpg")
      ig = copy.instagram_caption
      fb = copy.facebook_caption

      assert_includes email, body
      assert_includes ig, body
      assert_includes fb, body
      assert_includes email, "# #{@source.title}"
      assert_includes email, "[![#{@source.title}](https://example.com/composite.jpg)](#{edition_url})"
      assert_includes email, "[View this plate](#{edition_url})"
      assert_includes ig, @source.title
      assert_includes ig, Copy::AI_NOTICE
      assert_includes ig, "Model: Test Image."
      assert_includes ig, edition_url
      assert_includes fb, @source.title
      assert_includes fb, Copy::AI_NOTICE
      assert_includes fb, edition_url
      assert_no_match(/Branded share image/, ig)
      assert_operator ig.length, :<=, Copy::INSTAGRAM_CAPTION_LIMIT
    end
  end
end
