require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "about page renders" do
    get about_url
    assert_response :success
    assert_match "About", response.body
    assert_match "Colours are interpretive", response.body
    assert_match "Alexander Turnbull Library", response.body
  end
end
