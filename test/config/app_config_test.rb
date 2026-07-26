require "test_helper"

class AppConfigTest < ActiveSupport::TestCase
  test "prefers meta credentials over legacy instagram keys" do
    AppConfig.stub(:dig, lambda { |*keys|
      case keys
      when [ :meta, :page_access_token ] then "meta-token"
      when [ :meta, :instagram_user_id ] then "meta-ig"
      when [ :meta, :page_id ] then "meta-page"
      when [ :instagram, :access_token ] then "legacy-token"
      when [ :instagram, :user_id ] then "legacy-ig"
      end
    }) do
      assert_equal "meta-token", AppConfig.meta_page_access_token
      assert_equal "meta-ig", AppConfig.meta_instagram_user_id
      assert_equal "meta-page", AppConfig.meta_page_id
      assert AppConfig.instagram_configured?
      assert AppConfig.facebook_configured?
    end
  end

  test "falls back to legacy instagram credentials" do
    AppConfig.stub(:dig, lambda { |*keys|
      case keys
      when [ :instagram, :access_token ] then "legacy-token"
      when [ :instagram, :user_id ] then "legacy-ig"
      end
    }) do
      assert_equal "legacy-token", AppConfig.meta_page_access_token
      assert_equal "legacy-ig", AppConfig.meta_instagram_user_id
      assert_nil AppConfig.meta_page_id
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
end
