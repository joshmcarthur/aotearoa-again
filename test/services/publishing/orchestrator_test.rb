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

    class FakeInstagram
      attr_reader :calls

      def initialize
        @calls = []
      end

      def publish_photo(image_url:, caption:, alt_text: nil)
        @calls << { image_url: image_url, caption: caption, alt_text: alt_text }
        "ig_456"
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
      attach_fixture_image(@variant, name: :share_image)
      @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
      @edition.deliveries.create!(channel: "web", status: "pending")
      @edition.deliveries.create!(channel: "email", status: "pending")
      @edition.deliveries.create!(channel: "instagram", status: "pending")
    end

    test "publishes web email and instagram idempotently" do
      AppConfig.stub(:instagram_configured?, true) do
        buttondown = FakeButtondown.new
        instagram = FakeInstagram.new
        Orchestrator.new(@edition, buttondown: buttondown, instagram: instagram).call

        @edition.reload
        assert_equal "published", @edition.state
        assert_equal "succeeded", @edition.deliveries.find_by(channel: "web").status
        email = @edition.deliveries.find_by(channel: "email")
        assert_equal "succeeded", email.status
        assert_equal "bd_123", email.external_id
        ig = @edition.deliveries.find_by(channel: "instagram")
        assert_equal "succeeded", ig.status
        assert_equal "ig_456", ig.external_id
        assert_equal 1, buttondown.calls.size
        assert_equal 1, instagram.calls.size
        assert_equal @source.title, buttondown.calls.first[:subject]
        assert_includes buttondown.calls.first[:body], "/share.jpg"
        assert_includes instagram.calls.first[:image_url], "/share.jpg"
        assert_includes instagram.calls.first[:caption], @source.title

        Orchestrator.new(@edition, buttondown: buttondown, instagram: instagram).call
        assert_equal 1, buttondown.calls.size
        assert_equal 1, instagram.calls.size
      end
    end

    test "skips instagram when not configured" do
      buttondown = FakeButtondown.new
      instagram = FakeInstagram.new

      AppConfig.stub(:instagram_configured?, false) do
        Orchestrator.new(@edition, buttondown: buttondown, instagram: instagram).call
      end

      @edition.reload
      assert_equal "published", @edition.state
      assert_nil @edition.deliveries.find_by(channel: "instagram")
      assert_equal 0, instagram.calls.size
      assert_equal "succeeded", @edition.deliveries.find_by(channel: "email").status
    end

    test "fails edition when instagram delivery fails" do
      AppConfig.stub(:instagram_configured?, true) do
        buttondown = FakeButtondown.new
        instagram = Object.new
        def instagram.publish_photo(**)
          raise InstagramClient::Error, "token expired"
        end

        Orchestrator.new(@edition, buttondown: buttondown, instagram: instagram).call

        @edition.reload
        assert_equal "failed", @edition.state
        assert_equal "succeeded", @edition.deliveries.find_by(channel: "email").status
        ig = @edition.deliveries.find_by(channel: "instagram")
        assert_equal "failed", ig.status
        assert_match(/token expired/, ig.error_message)
      end
    end
  end
end
