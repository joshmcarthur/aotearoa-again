require "test_helper"

class AppConfigTest < ActiveSupport::TestCase
  test "reads meta credentials for channel gates" do
    AppConfig.stub(:dig, lambda { |*keys|
      case keys
      when [ :meta, :page_access_token ] then "meta-token"
      when [ :meta, :instagram_user_id ] then "meta-ig"
      when [ :meta, :page_id ] then "meta-page"
      end
    }) do
      assert_equal "meta-token", AppConfig.meta_page_access_token
      assert_equal "meta-ig", AppConfig.meta_instagram_user_id
      assert_equal "meta-page", AppConfig.meta_page_id
      assert AppConfig.instagram_configured?
      assert AppConfig.facebook_configured?
    end
  end

  test "instagram configured without facebook page id" do
    AppConfig.stub(:dig, lambda { |*keys|
      case keys
      when [ :meta, :page_access_token ] then "meta-token"
      when [ :meta, :instagram_user_id ] then "meta-ig"
      end
    }) do
      assert AppConfig.instagram_configured?
      assert_not AppConfig.facebook_configured?
    end
  end

  test "facebook requires page id with token" do
    AppConfig.stub(:dig, lambda { |*keys|
      case keys
      when [ :meta, :page_access_token ] then "meta-token"
      end
    }) do
      assert_not AppConfig.facebook_configured?
      assert_not AppConfig.instagram_configured?
    end
  end

  test "reads optional social profile urls" do
    AppConfig.stub(:dig, lambda { |*keys|
      case keys
      when [ :app, :instagram_url ] then "https://www.instagram.com/aotearoaagain"
      when [ :app, :facebook_url ] then "https://www.facebook.com/aotearoaagain"
      end
    }) do
      assert_equal "https://www.instagram.com/aotearoaagain", AppConfig.instagram_url
      assert_equal "https://www.facebook.com/aotearoaagain", AppConfig.facebook_url
    end
  end
end
