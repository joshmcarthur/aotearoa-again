require "test_helper"

module Publishing
  class OrchestratorTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

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
      attr_reader :photo_calls, :reel_calls

      def initialize
        @photo_calls = []
        @reel_calls = []
      end

      def publish_photo(image_url:, caption:, alt_text: nil)
        @photo_calls << { image_url: image_url, caption: caption, alt_text: alt_text }
        "ig_456"
      end

      def publish_reel(video_url:, caption:, cover_url: nil, share_to_feed: false)
        @reel_calls << {
          video_url: video_url,
          caption: caption,
          cover_url: cover_url,
          share_to_feed: share_to_feed
        }
        "ig_reel_999"
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
      attach_fixture_video(@variant)
      @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
      @edition.deliveries.create!(channel: "web", status: "pending")
      @edition.deliveries.create!(channel: "email", status: "pending")
      @edition.deliveries.create!(channel: "instagram", status: "pending")
      @edition.deliveries.create!(channel: "instagram_reel", status: "pending")
      @edition.deliveries.create!(channel: "facebook", status: "pending")
    end

    test "publishes web email instagram reel and facebook idempotently" do
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
          reel = @edition.deliveries.find_by(channel: "instagram_reel")
          assert_equal "succeeded", reel.status
          assert_equal "ig_reel_999", reel.external_id
          fb = @edition.deliveries.find_by(channel: "facebook")
          assert_equal "succeeded", fb.status
          assert_equal "fb_789", fb.external_id
          assert_equal 1, email.calls.size
          assert_equal 1, instagram.photo_calls.size
          assert_equal 1, instagram.reel_calls.size
          assert_equal 1, facebook.calls.size
          assert_includes instagram.reel_calls.first[:video_url], "/share.mp4"
          assert_includes instagram.reel_calls.first[:cover_url], "/share.jpg"
          assert_equal false, instagram.reel_calls.first[:share_to_feed]

          Orchestrator.new(
            @edition,
            email_client: email,
            instagram_client: instagram,
            facebook_client: facebook
          ).call
          assert_equal 1, email.calls.size
          assert_equal 1, instagram.photo_calls.size
          assert_equal 1, instagram.reel_calls.size
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
      assert_nil @edition.deliveries.find_by(channel: "instagram_reel")
      assert_nil @edition.deliveries.find_by(channel: "facebook")
      assert_equal 0, instagram.photo_calls.size
      assert_equal 0, instagram.reel_calls.size
      assert_equal 0, facebook.calls.size
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
      assert_nil @edition.deliveries.find_by(channel: "instagram_reel")
      assert_nil @edition.deliveries.find_by(channel: "facebook")
    end

    test "fails edition when instagram delivery fails" do
      AppConfig.stub(:instagram_configured?, true) do
        AppConfig.stub(:facebook_configured?, false) do
          email = FakeEmailClient.new
          instagram = Object.new
          def instagram.publish_photo(**)
            raise Deliveries::Instagram::Client::Error, "token expired"
          end
          def instagram.publish_reel(**)
            "ig_reel_unused"
          end

          Orchestrator.new(@edition, email_client: email, instagram_client: instagram).call

          @edition.reload
          assert_equal "failed", @edition.state
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
          fb = @edition.deliveries.find_by(channel: "facebook")
          assert_equal "failed", fb.status
          assert_match(/pages_manage_posts missing/, fb.error_message)
        end
      end
    end

    test "publishes edition when reel is missing but alerts admin" do
      @variant.share_video.purge

      AppConfig.stub(:instagram_configured?, true) do
        AppConfig.stub(:facebook_configured?, false) do
          email = FakeEmailClient.new
          instagram = FakeInstagramClient.new

          assert_enqueued_emails 1 do
            Orchestrator.new(@edition, email_client: email, instagram_client: instagram).call
          end

          @edition.reload
          assert_equal "published", @edition.state
          assert_equal "succeeded", @edition.deliveries.find_by(channel: "instagram").status
          reel = @edition.deliveries.find_by(channel: "instagram_reel")
          assert_equal "failed", reel.status
          assert_match(/Share video missing/, reel.error_message)
          assert_equal 0, instagram.reel_calls.size
        end
      end
    end

    test "publishes edition when reel meta call fails but alerts admin" do
      AppConfig.stub(:instagram_configured?, true) do
        AppConfig.stub(:facebook_configured?, false) do
          email = FakeEmailClient.new
          instagram = Object.new
          def instagram.publish_photo(**)
            "ig_456"
          end
          def instagram.publish_reel(**)
            raise Deliveries::Instagram::Client::Error, "reel rejected"
          end

          assert_enqueued_emails 1 do
            Orchestrator.new(@edition, email_client: email, instagram_client: instagram).call
          end

          @edition.reload
          assert_equal "published", @edition.state
          assert_equal "succeeded", @edition.deliveries.find_by(channel: "instagram").status
          reel = @edition.deliveries.find_by(channel: "instagram_reel")
          assert_equal "failed", reel.status
          assert_match(/reel rejected/, reel.error_message)
        end
      end
    end
  end
end
