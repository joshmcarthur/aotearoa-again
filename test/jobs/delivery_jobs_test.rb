require "test_helper"

class DeliveryJobsTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  DELIVERY_JOBS = [
    DeliverWebJob,
    DeliverEmailJob,
    DeliverInstagramJob,
    DeliverInstagramReelJob,
    DeliverFacebookJob,
    FinalizeEditionPublishJob
  ].freeze

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
    %w[web email instagram instagram_reel facebook].each do |channel|
      @edition.deliveries.create!(channel: channel, status: "pending")
    end
  end

  def stub_clients(email:, instagram:, facebook: FakeFacebookClient.new, &)
    Buttondown::Client.stub(:new, email) do
      Instagram::Client.stub(:new, instagram) do
        Facebook::Client.stub(:new, facebook, &)
      end
    end
  end

  def deliver_all(email:, instagram:, facebook: FakeFacebookClient.new)
    stub_clients(email:, instagram:, facebook:) do
      perform_enqueued_jobs only: DELIVERY_JOBS do
        @edition.deliveries.each(&:enqueue!)
      end
    end
  end

  test "delivers each channel idempotently and finalizes publish" do
    email = FakeEmailClient.new
    instagram = FakeInstagramClient.new
    facebook = FakeFacebookClient.new

    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, true) do
        deliver_all(email:, instagram:, facebook:)
      end
    end

    @edition.reload
    assert_equal "published", @edition.state
    assert_equal "bd_123", @edition.deliveries.find_by(channel: "email").external_id
    assert_equal "ig_456", @edition.deliveries.find_by(channel: "instagram").external_id
    assert_equal "ig_reel_999", @edition.deliveries.find_by(channel: "instagram_reel").external_id
    assert_equal "fb_789", @edition.deliveries.find_by(channel: "facebook").external_id
    assert_includes instagram.reel_calls.first[:video_url], "/share.mp4"
    assert_equal false, instagram.reel_calls.first[:share_to_feed]

    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, true) do
        stub_clients(email:, instagram:, facebook:) do
          DeliverEmailJob.perform_now(@edition.id)
          DeliverInstagramJob.perform_now(@edition.id)
          DeliverInstagramReelJob.perform_now(@edition.id)
          DeliverFacebookJob.perform_now(@edition.id)
        end
      end
    end
    assert_equal [ 1, 1, 1, 1 ], [ email.calls.size, instagram.photo_calls.size, instagram.reel_calls.size, facebook.calls.size ]
  end

  test "skips inapplicable meta channels" do
    AppConfig.stub(:instagram_configured?, false) do
      AppConfig.stub(:facebook_configured?, false) do
        deliver_all(email: FakeEmailClient.new, instagram: FakeInstagramClient.new)
      end
    end

    @edition.reload
    assert_equal "published", @edition.state
    assert_nil @edition.deliveries.find_by(channel: "instagram")
    assert_nil @edition.deliveries.find_by(channel: "facebook")
  end

  test "publishes edition when a channel fails after retries and alerts admin" do
    failing = Object.new
    def failing.publish_photo(**) = raise(Instagram::Client::Error, "token expired")
    def failing.publish_reel(**) = "unused"

    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, false) do
        assert_enqueued_emails 1 do
          deliver_all(email: FakeEmailClient.new, instagram: failing)
        end
      end
    end

    @edition.reload
    assert_equal "published", @edition.state
    ig = @edition.deliveries.find_by(channel: "instagram")
    assert_equal "failed", ig.status
    assert_match(/token expired/, ig.error_message)
  end

  test "marks missing share video as failed without retrying" do
    @variant.share_video.purge

    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, true) do
        deliver_all(email: FakeEmailClient.new, instagram: FakeInstagramClient.new)
      end
    end

    reel = @edition.deliveries.find_by(channel: "instagram_reel")
    assert_equal "published", @edition.reload.state
    assert_equal "failed", reel.status
    assert_match(/Share video missing/, reel.error_message)
  end

  test "manual retry re-attempts a failed delivery via its job class" do
    delivery = @edition.deliveries.find_by(channel: "email")
    delivery.fail!("temporary")
    email = FakeEmailClient.new

    Buttondown::Client.stub(:new, email) do
      DeliverEmailJob.perform_now(@edition.id)
    end

    assert_equal "succeeded", delivery.reload.status
    assert_equal "bd_123", delivery.external_id
  end
end
