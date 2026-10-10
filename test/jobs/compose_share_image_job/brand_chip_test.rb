require "test_helper"

class ComposeShareImageJob
  class BrandChipTest < ActiveSupport::TestCase
    test "attribution line uses the source content partner" do
      line = BrandChip.attribution_line(
        "Wellington City Council Archives",
        "http://www.example.com/s/abc123"
      )
      assert_equal "AI colourised · Wellington City Council Archives · http://www.example.com/s/abc123", line
      assert_no_match(/National Library of New Zealand/, line)
    end

    test "attribution line falls back when partner is blank" do
      line = BrandChip.attribution_line(nil, "http://www.example.com/s/abc123")
      assert_equal "AI colourised · Alexander Turnbull Library · http://www.example.com/s/abc123", line
    end
  end
end
