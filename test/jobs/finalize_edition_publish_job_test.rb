require "test_helper"

class FinalizeEditionPublishJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/finalize-image-model",
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

  test "alerts admin when any delivery failed" do
    @edition.deliveries.create!(channel: "web", status: "succeeded")
    @edition.deliveries.create!(channel: "email", status: "failed", error_message: "boom")

    assert_enqueued_emails 1 do
      FinalizeEditionPublishJob.perform_now(@edition.id)
    end
  end

  test "does not alert when all deliveries succeeded" do
    @edition.deliveries.create!(channel: "web", status: "succeeded")
    @edition.deliveries.create!(channel: "email", status: "succeeded")

    assert_no_enqueued_emails do
      FinalizeEditionPublishJob.perform_now(@edition.id)
    end
  end

  test "no-ops when deliveries are still pending" do
    @edition.deliveries.create!(channel: "web", status: "succeeded")
    @edition.deliveries.create!(channel: "email", status: "pending")

    assert_no_enqueued_emails do
      FinalizeEditionPublishJob.perform_now(@edition.id)
    end
  end

  test "no-ops when edition is not published" do
    @edition.update!(state: "scheduled")
    @edition.deliveries.create!(channel: "web", status: "failed", error_message: "boom")

    assert_no_enqueued_emails do
      FinalizeEditionPublishJob.perform_now(@edition.id)
    end
  end
end
