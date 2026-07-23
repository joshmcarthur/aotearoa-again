require "test_helper"

class ColouriseCandidateJobTest < ActiveJob::TestCase
  class FakeColouriser
    def call(attachment:, model:)
      {
        model: model,
        prompt: Colourisers::Prompt::TEXT,
        io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg"))),
        filename: "colourised.jpg",
        content_type: "image/jpeg"
      }
    end
  end

  setup do
    @model = Model.create!(
      model_id: "test/colourise-enqueue-#{SecureRandom.hex(4)}",
      name: "Test Image",
      provider: "openrouter",
      preferred_for_colourise: true,
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item
    @candidate = @source.candidates.create!(status: "pending_colour")
    attach_fixture_image(@candidate)
  end

  test "enqueues compose share image job after colourise" do
    Colourisers::RubyLlmColouriser.define_singleton_method(:new) { FakeColouriser.new }

    assert_enqueued_with(job: ComposeShareImageJob) do
      ColouriseCandidateJob.perform_now(@candidate.id, model_ids: [ @model.id ])
    end

    @candidate.reload
    assert_equal "ready", @candidate.status
    assert @candidate.variants.first.colourised_image.attached?
  ensure
    Colourisers::RubyLlmColouriser.singleton_class.remove_method(:new)
  end
end
