require "test_helper"

module Publishing
  class FinalizeEditionTest < ActiveSupport::TestCase
    setup do
      @model = Model.openrouter.image_capable.first || Model.create!(
        model_id: "test/finalize-edition-model",
        name: "Test Image",
        provider: "openrouter",
        modalities: { "input" => [ "image" ], "output" => [ "image" ] }
      )
      @source = create_source_item
      @candidate = @source.candidates.create!(status: "ready")
      @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(@variant, name: :colourised_image)
      @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "published")
      @edition.deliveries.create!(channel: "web", status: "succeeded")
      @edition.deliveries.create!(channel: "email", status: "succeeded")
    end

    test "enqueues finalize job when edition is published and deliveries are terminal" do
      assert_enqueued_with(job: FinalizeEditionPublishJob, args: [ @edition.id ]) do
        FinalizeEdition.enqueue_if_ready(@edition.id)
      end
    end

    test "does not enqueue when edition is still scheduled" do
      @edition.update!(state: "scheduled")

      assert_no_enqueued_jobs only: FinalizeEditionPublishJob do
        FinalizeEdition.enqueue_if_ready(@edition.id)
      end
    end

    test "does not enqueue when deliveries are pending" do
      @edition.deliveries.find_by(channel: "email").update!(status: "pending")

      assert_no_enqueued_jobs only: FinalizeEditionPublishJob do
        FinalizeEdition.enqueue_if_ready(@edition.id)
      end
    end
  end
end
