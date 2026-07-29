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
    @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
  end

  test "publishes when all deliveries are terminal" do
    @edition.deliveries.create!(channel: "web", status: "succeeded")
    @edition.deliveries.create!(channel: "email", status: "succeeded")

    FinalizeEditionPublishJob.perform_now(@edition.id)

    assert_equal "published", @edition.reload.state
  end

  test "alerts admin when any delivery failed" do
    @edition.deliveries.create!(channel: "web", status: "succeeded")
    @edition.deliveries.create!(channel: "email", status: "failed", error_message: "boom")

    assert_enqueued_emails 1 do
      FinalizeEditionPublishJob.perform_now(@edition.id)
    end

    assert_equal "published", @edition.reload.state
  end

  test "no-ops when deliveries are still pending" do
    @edition.deliveries.create!(channel: "web", status: "succeeded")
    @edition.deliveries.create!(channel: "email", status: "pending")

    FinalizeEditionPublishJob.perform_now(@edition.id)

    assert_equal "scheduled", @edition.reload.state
  end

  test "no-ops when already published" do
    @edition.publish!
    @edition.deliveries.create!(channel: "web", status: "succeeded")

    FinalizeEditionPublishJob.perform_now(@edition.id)

    assert_equal "published", @edition.reload.state
  end
end
