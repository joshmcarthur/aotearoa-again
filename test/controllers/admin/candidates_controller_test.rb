require "test_helper"

module Admin
  class CandidatesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @model = Model.openrouter.image_capable.first || Model.create!(
        model_id: "test/image-model",
        name: "Test Image",
        provider: "openrouter",
        modalities: { "input" => [ "image" ], "output" => [ "image" ] }
      )
      @source = create_source_item
      @candidate = @source.candidates.create!(status: "ready")
      attach_fixture_image(@candidate)
      @variant = @candidate.variants.create!(model: @model, prompt: "colourise")
      attach_fixture_image(@variant, name: :colourised_image)
    end

    test "requires authentication" do
      get admin_candidates_url
      assert_response :unauthorized
    end

    test "index succeeds when authenticated" do
      get admin_candidates_url, headers: basic_auth
      assert_response :success
      assert_match @source.title, response.body
    end

    test "approve schedules edition" do
      post approve_admin_candidate_url(@candidate), params: { variant_id: @variant.id }, headers: basic_auth
      assert_redirected_to admin_candidates_path
      assert Edition.exists?(variant: @variant)
    end

    private

    def basic_auth
      {
        "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(
          AppConfig.admin_username,
          AppConfig.admin_password
        )
      }
    end
  end
end
