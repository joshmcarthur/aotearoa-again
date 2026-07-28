require "test_helper"

module Admin
  class EditionsControllerTest < ActionDispatch::IntegrationTest
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
      @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(@variant, name: :colourised_image)
      attach_fixture_image(@variant, name: :composite_image)
      attach_fixture_image(@variant, name: :share_image)
      @variant.create_share_link!
      @edition = Edition.create!(
        variant: @variant,
        publish_on: Time.zone.tomorrow,
        state: "scheduled"
      )
    end

    test "requires authentication" do
      get admin_editions_url
      assert_response :unauthorized
    end

    test "index succeeds when authenticated" do
      get admin_editions_url, headers: basic_auth
      assert_response :success
      assert_match @source.title, response.body
      assert_match admin_edition_path(@edition), response.body
    end

    test "show renders all four image variant labels" do
      get admin_edition_url(@edition), headers: basic_auth
      assert_response :success
      assert_match "Original", response.body
      assert_match "Colourised", response.body
      assert_match "Share (unbranded)", response.body
      assert_match "Branded", response.body
      assert_match @variant.share_link.path, response.body
    end

    test "show renders share video when attached" do
      attach_fixture_video(@variant)
      get admin_edition_url(@edition), headers: basic_auth
      assert_response :success
      assert_match "Share video", response.body
      assert_select "video source[type=?]", "video/mp4"
    end

    test "regenerate enqueues share image and video jobs" do
      assert_enqueued_with(job: ComposeShareImageJob, args: [ @variant.id ]) do
        assert_enqueued_with(job: ComposeShareVideoJob, args: [ @variant.id ]) do
          post regenerate_admin_edition_url(@edition), headers: basic_auth
        end
      end
      assert_redirected_to admin_edition_path(@edition)
      assert_equal "Share assets queued", flash[:notice]
    end

    test "show renders empty state when attachments are missing" do
      bare_source = create_source_item(title: "Bare edition")
      bare_candidate = bare_source.candidates.create!(status: "ready")
      bare_variant = bare_candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      bare_edition = Edition.create!(
        variant: bare_variant,
        publish_on: Time.zone.tomorrow + 2.days,
        state: "scheduled"
      )

      get admin_edition_url(bare_edition), headers: basic_auth
      assert_response :success
      assert_equal 5, response.body.scan("Not available yet").size
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
