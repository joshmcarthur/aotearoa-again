require "test_helper"

module Publishing
  class OrchestratorTest < ActiveSupport::TestCase
    class FakeEmailClient
      attr_reader :calls

      def initialize
        @calls = []
      end

      def create_and_send(subject:, body:)
        @calls << { subject: subject, body: body }
        { "id" => "bd_123" }
      end
    end

    class FakeInstagramClient
      attr_reader :calls

      def initialize
        @calls = []
      end

      def publish_photo(image_url:, caption:, alt_text: nil)
        @calls << { image_url: image_url, caption: caption, alt_text: alt_text }
        "ig_456"
      end
    end

    class FakeFacebookClient
      attr_reader :calls

      def initialize
        @calls = []
      end

      def publish_photo(image_url:, caption:)
        @calls << { image_url: image_url, caption: caption }
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
          email = FakeEmailClient.new
          instagram = FakeInstagramClient.new
          facebook = FakeFacebookClient.new
          Orchestrator.new(
            @edition,
            email_client: email,
            instagram_client: instagram,
            facebook_client: facebook
          ).call

          @edition.reload
          assert_equal "published", @edition.state
          assert_equal "succeeded", @edition.deliveries.find_by(channel: "web").status
          email_delivery = @edition.deliveries.find_by(channel: "email")
          assert_equal "succeeded", email_delivery.status
          assert_equal "bd_123", email_delivery.external_id
          ig = @edition.deliveries.find_by(channel: "instagram")
          assert_equal "succeeded", ig.status
          assert_equal "ig_456", ig.external_id
          fb = @edition.deliveries.find_by(channel: "facebook")
          assert_equal "succeeded", fb.status
          assert_equal "fb_789", fb.external_id
          assert_equal 1, email.calls.size
          assert_equal 1, instagram.calls.size
          assert_equal 1, facebook.calls.size
          assert_equal @source.title, email.calls.first[:subject]
          edition_url = Rails.application.routes.url_helpers.edition_url(@edition)
          assert_includes email.calls.first[:body], "/composite.jpg"
          assert_includes email.calls.first[:body], "[![#{@source.title}]"
          assert_includes email.calls.first[:body], "](#{edition_url})"
          assert_includes instagram.calls.first[:image_url], "/share.jpg"
          assert_includes instagram.calls.first[:caption], @source.title
          assert_includes facebook.calls.first[:image_url], "/share.jpg"
          assert_includes facebook.calls.first[:caption], @source.title

          Orchestrator.new(
            @edition,
            email_client: email,
            instagram_client: instagram,
            facebook_client: facebook
          ).call
          assert_equal 1, email.calls.size
          assert_equal 1, instagram.calls.size
          assert_equal 1, facebook.calls.size
        end
      end
    end

    test "skips instagram and facebook when not configured" do
      email = FakeEmailClient.new
      instagram = FakeInstagramClient.new
      facebook = FakeFacebookClient.new

      AppConfig.stub(:instagram_configured?, false) do
        AppConfig.stub(:facebook_configured?, false) do
          Orchestrator.new(
            @edition,
            email_client: email,
            instagram_client: instagram,
            facebook_client: facebook
          ).call
        end
      end

      @edition.reload
      assert_equal "published", @edition.state
      assert_nil @edition.deliveries.find_by(channel: "instagram")
      assert_nil @edition.deliveries.find_by(channel: "facebook")
      assert_equal 0, instagram.calls.size
      assert_equal 0, facebook.calls.size
      assert_equal "succeeded", @edition.deliveries.find_by(channel: "email").status
    end

    test "skips meta channels without commercial use" do
      @source.update!(usage_flags: %w[Modify Share])
      email = FakeEmailClient.new
      instagram = FakeInstagramClient.new
      facebook = FakeFacebookClient.new

      AppConfig.stub(:instagram_configured?, true) do
        AppConfig.stub(:facebook_configured?, true) do
          Orchestrator.new(
            @edition,
            email_client: email,
            instagram_client: instagram,
            facebook_client: facebook
          ).call
        end
      end

      @edition.reload
      assert_equal "published", @edition.state
      assert_nil @edition.deliveries.find_by(channel: "instagram")
      assert_nil @edition.deliveries.find_by(channel: "facebook")
      assert_equal 0, instagram.calls.size
      assert_equal 0, facebook.calls.size
      assert_equal "succeeded", @edition.deliveries.find_by(channel: "email").status
    end

    test "fails edition when instagram delivery fails" do
      AppConfig.stub(:instagram_configured?, true) do
        AppConfig.stub(:facebook_configured?, false) do
          email = FakeEmailClient.new
          instagram = Object.new
          def instagram.publish_photo(**)
            raise Deliveries::Instagram::Client::Error, "token expired"
          end

          Orchestrator.new(@edition, email_client: email, instagram_client: instagram).call

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
          email = FakeEmailClient.new
          facebook = Object.new
          def facebook.publish_photo(**)
            raise Deliveries::Facebook::Client::Error, "pages_manage_posts missing"
          end

          Orchestrator.new(@edition, email_client: email, facebook_client: facebook).call

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
