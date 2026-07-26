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

    test "email_markdown links to edition and archive on the site" do
      source = create_source_item
      copy = Copy.new(source)
      body = copy.email_markdown(
        edition_url: "https://aotearoa-again.example/editions/2026-07-26",
        archive_url: "https://aotearoa-again.example/editions"
      )

      assert_includes body, "[View this plate](https://aotearoa-again.example/editions/2026-07-26)"
      assert_includes body, "[View the archive](https://aotearoa-again.example/editions)"
    end
  end
end
