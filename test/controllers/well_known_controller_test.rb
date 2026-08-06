require "test_helper"

class WellKnownControllerTest < ActionDispatch::IntegrationTest
  test "returns publication at-uri as plain text" do
    AppConfig.stub(:bluesky_publication_uri, "at://did:plc:test/site.standard.publication/pub1") do
      get "/.well-known/site.standard.publication"
    end

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "at://did:plc:test/site.standard.publication/pub1", response.body
  end

  test "returns not found when publication uri is missing" do
    AppConfig.stub(:bluesky_publication_uri, nil) do
      get "/.well-known/site.standard.publication"
    end

    assert_response :not_found
  end
end
