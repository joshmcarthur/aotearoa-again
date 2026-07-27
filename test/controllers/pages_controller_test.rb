require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "about page renders" do
    get about_url
    assert_response :success
    assert_match "About", response.body
    assert_match "Colours are interpretive", response.body
    assert_match "Alexander Turnbull Library", response.body
  end

  test "nav includes social links when configured" do
    AppConfig.stub(:instagram_url, "https://www.instagram.com/aotearoaagain") do
      AppConfig.stub(:facebook_url, "https://www.facebook.com/aotearoaagain") do
        get about_url
        assert_response :success
        assert_match 'href="https://www.instagram.com/aotearoaagain"', response.body
        assert_match 'href="https://www.facebook.com/aotearoaagain"', response.body
        assert_match 'aria-label="Instagram"', response.body
        assert_match 'aria-label="Facebook"', response.body
        assert_match 'viewBox="0 0 24 24"', response.body
        assert_match "aa-nav-icon-svg", response.body
      end
    end
  end

  test "nav omits social links when not configured" do
    AppConfig.stub(:instagram_url, nil) do
      AppConfig.stub(:facebook_url, nil) do
        get about_url
        assert_response :success
        assert_no_match 'aria-label="Instagram"', response.body
        assert_no_match 'aria-label="Facebook"', response.body
        assert_no_match "aa-nav-icon-svg", response.body
      end
    end
  end
end
