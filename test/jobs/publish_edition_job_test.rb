require "test_helper"

class PublishEditionJobTest < ActiveJob::TestCase
  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/publish-image-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item
    @candidate = @source.candidates.create!(status: "ready")
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
    @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
    @edition.deliveries.create!(channel: "web", status: "pending")
    @edition.deliveries.create!(channel: "email", status: "pending")
  end

  test "enqueues the channel job for each delivery" do
    assert_enqueued_with(job: DeliverWebJob, args: [ @edition.id ]) do
      assert_enqueued_with(job: DeliverEmailJob, args: [ @edition.id ]) do
        PublishEditionJob.perform_now(Time.zone.today)
      end
    end
  end

  test "does not enqueue skipped deliveries" do
    @edition.deliveries.create!(channel: "instagram", status: "skipped")

    assert_no_enqueued_jobs only: DeliverInstagramJob do
      assert_enqueued_with(job: DeliverWebJob, args: [ @edition.id ]) do
        PublishEditionJob.perform_now(Time.zone.today)
      end
    end
  end

  test "no-ops when no scheduled edition for date" do
    assert_no_enqueued_jobs only: [ DeliverWebJob, DeliverEmailJob ] do
      PublishEditionJob.perform_now(Time.zone.tomorrow)
    end
  end
end
