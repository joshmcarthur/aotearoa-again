require "test_helper"

class NotifyDeliveryFailureJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/notify-failure-job-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item
    @candidate = @source.candidates.create!(status: "ready")
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
    @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "published")
    @delivery = @edition.deliveries.create!(channel: "instagram", status: "failed", error_message: "boom")
  end

  test "sends email for failed delivery on published edition" do
    assert_emails 1 do
      NotifyDeliveryFailureJob.perform_now(@delivery.id)
    end
  end

  test "does not send email when delivery is not failed" do
    @delivery.update!(status: "succeeded")

    assert_no_emails do
      NotifyDeliveryFailureJob.perform_now(@delivery.id)
    end
  end

  test "does not send email when edition is not published" do
    @edition.update!(state: "scheduled")

    assert_no_emails do
      NotifyDeliveryFailureJob.perform_now(@delivery.id)
    end
  end

  test "fail! enqueues alert job when edition is published" do
    delivery = @edition.deliveries.create!(channel: "email", status: "pending")

    assert_enqueued_with(job: NotifyDeliveryFailureJob, args: [ delivery.id ]) do
      delivery.fail!("temporary")
    end
  end

  test "fail! does not enqueue alert job when edition is not published" do
    @edition.update!(state: "scheduled")
    delivery = @edition.deliveries.create!(channel: "email", status: "pending")

    assert_no_enqueued_jobs(only: NotifyDeliveryFailureJob) do
      delivery.fail!("temporary")
    end
  end
end
