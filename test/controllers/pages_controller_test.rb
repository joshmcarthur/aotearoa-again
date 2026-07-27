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
        assert_match 'href="/subscribe"', response.body
        assert_match "aa-nav-cta", response.body
        assert_select "nav.aa-nav a[href='https://www.instagram.com/aotearoaagain'][aria-label='Instagram']"
        assert_select "nav.aa-nav a[href='https://www.facebook.com/aotearoaagain'][aria-label='Facebook']"
        assert_select "footer.aa-footer a[href='https://www.instagram.com/aotearoaagain'][aria-label='Instagram (@aotearoaagain)']", text: /@aotearoaagain/
        assert_select "footer.aa-footer a[href='https://www.facebook.com/aotearoaagain'][aria-label='Facebook (@aotearoaagain)']", text: /@aotearoaagain/
      end
    end
  end

  test "nav omits social links when not configured" do
    AppConfig.stub(:instagram_url, nil) do
      AppConfig.stub(:facebook_url, nil) do
        get about_url
        assert_response :success
        assert_select "nav.aa-nav a[aria-label='Instagram']", count: 0
        assert_select "nav.aa-nav a[aria-label='Facebook']", count: 0
        assert_select "footer.aa-footer a[aria-label='Instagram']", count: 0
        assert_select "footer.aa-footer a[aria-label='Facebook']", count: 0
        assert_no_match "aa-footer-social", response.body
      end
    end
  end
end
