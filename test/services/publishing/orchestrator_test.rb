require "test_helper"

module Publishing
  class OrchestratorTest < ActiveSupport::TestCase
    class FakeButtondown
      attr_reader :calls

      def initialize
        @calls = []
      end

      def create_and_send(subject:, body:)
        @calls << { subject: subject, body: body }
        { "id" => "bd_123" }
      end
    end

    class FakeMeta
      attr_reader :instagram_calls, :facebook_calls

      def initialize
        @instagram_calls = []
        @facebook_calls = []
      end

      def publish_instagram_photo(image_url:, caption:, alt_text: nil)
        @instagram_calls << { image_url: image_url, caption: caption, alt_text: alt_text }
        "ig_456"
      end

      def publish_facebook_photo(image_url:, caption:)
        @facebook_calls << { image_url: image_url, caption: caption }
        "fb_789"
      end
    end

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
      @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
      @edition.deliveries.create!(channel: "web", status: "pending")
      @edition.deliveries.create!(channel: "email", status: "pending")
      @edition.deliveries.create!(channel: "instagram", status: "pending")
      @edition.deliveries.create!(channel: "facebook", status: "pending")
    end

    test "publishes web email instagram and facebook idempotently" do
      AppConfig.stub(:instagram_configured?, true) do
        AppConfig.stub(:facebook_configured?, true) do
          buttondown = FakeButtondown.new
          meta = FakeMeta.new
          Orchestrator.new(@edition, buttondown: buttondown, meta: meta).call

          @edition.reload
          assert_equal "published", @edition.state
          assert_equal "succeeded", @edition.deliveries.find_by(channel: "web").status
          email = @edition.deliveries.find_by(channel: "email")
          assert_equal "succeeded", email.status
          assert_equal "bd_123", email.external_id
          ig = @edition.deliveries.find_by(channel: "instagram")
          assert_equal "succeeded", ig.status
          assert_equal "ig_456", ig.external_id
          fb = @edition.deliveries.find_by(channel: "facebook")
          assert_equal "succeeded", fb.status
          assert_equal "fb_789", fb.external_id
          assert_equal 1, buttondown.calls.size
          assert_equal 1, meta.instagram_calls.size
          assert_equal 1, meta.facebook_calls.size
          assert_equal @source.title, buttondown.calls.first[:subject]
          edition_url = Rails.application.routes.url_helpers.edition_url(@edition)
          assert_includes buttondown.calls.first[:body], "/composite.jpg"
          assert_includes buttondown.calls.first[:body], "[![#{@source.title}]"
          assert_includes buttondown.calls.first[:body], "](#{edition_url})"
          assert_includes meta.instagram_calls.first[:image_url], "/share.jpg"
          assert_includes meta.instagram_calls.first[:caption], @source.title
          assert_includes meta.facebook_calls.first[:image_url], "/share.jpg"
          assert_includes meta.facebook_calls.first[:caption], @source.title

          Orchestrator.new(@edition, buttondown: buttondown, meta: meta).call
          assert_equal 1, buttondown.calls.size
          assert_equal 1, meta.instagram_calls.size
          assert_equal 1, meta.facebook_calls.size
        end
      end
    end

    test "skips instagram and facebook when not configured" do
      buttondown = FakeButtondown.new
      meta = FakeMeta.new

      AppConfig.stub(:instagram_configured?, false) do
        AppConfig.stub(:facebook_configured?, false) do
          Orchestrator.new(@edition, buttondown: buttondown, meta: meta).call
        end
      end

      @edition.reload
      assert_equal "published", @edition.state
      assert_nil @edition.deliveries.find_by(channel: "instagram")
      assert_nil @edition.deliveries.find_by(channel: "facebook")
      assert_equal 0, meta.instagram_calls.size
      assert_equal 0, meta.facebook_calls.size
      assert_equal "succeeded", @edition.deliveries.find_by(channel: "email").status
    end

    test "skips meta channels without commercial use" do
      @source.update!(usage_flags: %w[Modify Share])
      buttondown = FakeButtondown.new
      meta = FakeMeta.new

      AppConfig.stub(:instagram_configured?, true) do
        AppConfig.stub(:facebook_configured?, true) do
          Orchestrator.new(@edition, buttondown: buttondown, meta: meta).call
        end
      end

      @edition.reload
      assert_equal "published", @edition.state
      assert_nil @edition.deliveries.find_by(channel: "instagram")
      assert_nil @edition.deliveries.find_by(channel: "facebook")
      assert_equal 0, meta.instagram_calls.size
      assert_equal 0, meta.facebook_calls.size
      assert_equal "succeeded", @edition.deliveries.find_by(channel: "email").status
    end

    test "fails edition when instagram delivery fails" do
      AppConfig.stub(:instagram_configured?, true) do
        AppConfig.stub(:facebook_configured?, false) do
          buttondown = FakeButtondown.new
          meta = Object.new
          def meta.publish_instagram_photo(**)
            raise MetaClient::Error, "token expired"
          end

          Orchestrator.new(@edition, buttondown: buttondown, meta: meta).call

          @edition.reload
          assert_equal "failed", @edition.state
          assert_equal "succeeded", @edition.deliveries.find_by(channel: "email").status
          ig = @edition.deliveries.find_by(channel: "instagram")
          assert_equal "failed", ig.status
          assert_match(/token expired/, ig.error_message)
        end
      end
    end

    test "fails edition when facebook delivery fails" do
      AppConfig.stub(:instagram_configured?, false) do
        AppConfig.stub(:facebook_configured?, true) do
          buttondown = FakeButtondown.new
          meta = Object.new
          def meta.publish_facebook_photo(**)
            raise MetaClient::Error, "pages_manage_posts missing"
          end

          Orchestrator.new(@edition, buttondown: buttondown, meta: meta).call

          @edition.reload
          assert_equal "failed", @edition.state
          assert_equal "succeeded", @edition.deliveries.find_by(channel: "email").status
          fb = @edition.deliveries.find_by(channel: "facebook")
          assert_equal "failed", fb.status
          assert_match(/pages_manage_posts missing/, fb.error_message)
        end
      end
    end
  end
end
