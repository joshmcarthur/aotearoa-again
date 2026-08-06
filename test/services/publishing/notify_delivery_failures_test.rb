require "test_helper"

module Publishing
  class NotifyDeliveryFailuresTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @model = Model.openrouter.image_capable.first || Model.create!(
        model_id: "test/notify-failures-model",
        name: "Test Image",
        provider: "openrouter",
        modalities: { "input" => [ "image" ], "output" => [ "image" ] }
      )
      @source = create_source_item
      @candidate = @source.candidates.create!(status: "ready")
      @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(@variant, name: :colourised_image)
      @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "published")
    end

    test "alerts admin once when deliveries are terminal with failures" do
      @edition.deliveries.create!(channel: "email", status: "succeeded")
      @edition.deliveries.create!(channel: "instagram", status: "failed", error_message: "boom")

      assert_enqueued_emails 1 do
        NotifyDeliveryFailures.call(@edition.id)
      end

      assert_not_nil @edition.reload.delivery_alert_sent_at
    end

    test "does not alert when all deliveries succeeded" do
      @edition.deliveries.create!(channel: "email", status: "succeeded")
      @edition.deliveries.create!(channel: "instagram", status: "skipped")

      assert_no_enqueued_emails do
        NotifyDeliveryFailures.call(@edition.id)
      end
    end

    test "does not alert when deliveries are still pending" do
      @edition.deliveries.create!(channel: "email", status: "failed", error_message: "boom")
      @edition.deliveries.create!(channel: "instagram", status: "pending")

      assert_no_enqueued_emails do
        NotifyDeliveryFailures.call(@edition.id)
      end
    end

    test "does not alert when edition is not published" do
      @edition.update!(state: "scheduled")
      @edition.deliveries.create!(channel: "email", status: "failed", error_message: "boom")

      assert_no_enqueued_emails do
        NotifyDeliveryFailures.call(@edition.id)
      end
    end

    test "alerts only once when called repeatedly" do
      @edition.deliveries.create!(channel: "email", status: "failed", error_message: "boom")
      @edition.deliveries.create!(channel: "instagram", status: "skipped")

      assert_enqueued_emails 1 do
        NotifyDeliveryFailures.call(@edition.id)
        NotifyDeliveryFailures.call(@edition.id)
      end
    end
  end
end
