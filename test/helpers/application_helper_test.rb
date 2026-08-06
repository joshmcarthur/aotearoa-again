require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "social_handle_from_url extracts @handle from profile urls" do
    assert_equal "@aotearoa.again", social_handle_from_url("https://www.instagram.com/aotearoa.again/")
    assert_equal "@aotearoaagain", social_handle_from_url("https://www.facebook.com/aotearoaagain")
    assert_equal "@aotearoaagain", social_handle_from_url("https://www.youtube.com/@aotearoaagain")
    assert_equal "@aotearoa-again.example", social_handle_from_url("https://bsky.app/profile/aotearoa-again.example")
  end

  test "social_handle_from_url returns nil for blank or invalid urls" do
    assert_nil social_handle_from_url("")
    assert_nil social_handle_from_url("https://www.instagram.com/")
    assert_nil social_handle_from_url("https://bsky.app/profile/")
    assert_nil social_handle_from_url("not a url")
  end
end
