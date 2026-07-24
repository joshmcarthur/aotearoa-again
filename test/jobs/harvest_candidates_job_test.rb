require "test_helper"

class HarvestCandidatesJobTest < ActiveJob::TestCase
  class FakeHarvester
    def initialize(candidates)
      @candidates = candidates
    end

    def call
      candidate = @candidates.shift
      candidate.respond_to?(:call) ? candidate.call : candidate
    end
  end

  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/image-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
  end

  test "harvests when ready candidates are already in published editions" do
    3.times do |index|
      source = create_source_item(digitalnz_id: "published-#{index}", dedupe_key: "published-#{index}")
      candidate = source.candidates.create!(status: "ready")
      attach_fixture_image(candidate)
      variant = candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(variant, name: :colourised_image)
      Edition.create!(
        variant: variant,
        publish_on: (index + 1).days.ago.to_date,
        state: "published",
        published_at: (index + 1).days.ago
      )
    end

    test_case = self
    Digitalnz::Harvester.define_singleton_method(:new) do
      FakeHarvester.new([
        lambda {
          source = test_case.create_source_item(digitalnz_id: "fresh", dedupe_key: "fresh")
          candidate = source.candidates.create!(status: "pending_colour")
          test_case.attach_fixture_image(candidate)
          candidate
        }
      ])
    end

    assert_enqueued_with(job: ColouriseCandidateJob) do
      assert_equal 1, HarvestCandidatesJob.perform_now(target: 1)
    end
  ensure
    Digitalnz::Harvester.singleton_class.remove_method(:new)
  end
end
