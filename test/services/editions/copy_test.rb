require "test_helper"

module Editions
  class CopyTest < ActiveSupport::TestCase
    test "uses description as caption and builds attribution from metadata" do
      source = create_source_item
      copy = Copy.new(source)

      assert_equal source.title, copy.title
      assert_equal source.description, copy.caption
      assert_includes copy.attribution_text, "Alexander Turnbull Library"
      assert_includes copy.attribution_text, source.record_url
      assert_includes copy.attribution_text, "DigitalNZ"
      assert_equal Copy::AI_NOTICE, copy.ai_notice
    end

    test "falls back when description blank" do
      source = create_source_item(description: nil, display_date: "1901", placename: "Dunedin")
      copy = Copy.new(source)
      assert_includes copy.caption, "1901"
      assert_includes copy.caption, "Dunedin"
    end

    test "email instagram and facebook share the same narrative body" do
      source = create_source_item
      copy = Copy.new(source)
      edition_url = "https://example.com/editions/2026-07-25"
      body = copy.body_text

      assert_includes body, source.description
      assert_includes body, "Alexander Turnbull Library"
      assert_includes body, source.record_url

      email = copy.email_markdown(edition_url: edition_url, image_url: "https://example.com/composite.jpg")
      ig = copy.instagram_caption(edition_url: edition_url)
      fb = copy.facebook_caption(edition_url: edition_url)

      assert_includes email, body
      assert_includes ig, body
      assert_includes fb, body
      assert_includes email, "# #{source.title}"
      assert_includes email, "[![#{source.title}](https://example.com/composite.jpg)](#{edition_url})"
      assert_includes email, "[View this plate](#{edition_url})"
      assert_includes ig, source.title
      assert_includes ig, Copy::AI_NOTICE
      assert_includes ig, edition_url
      assert_includes fb, source.title
      assert_includes fb, Copy::AI_NOTICE
      assert_includes fb, edition_url
      assert_no_match(/Branded share image/, ig)
      assert_operator ig.length, :<=, Copy::INSTAGRAM_CAPTION_LIMIT
    end
  end
end
