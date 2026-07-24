require "test_helper"

class HarvestCandidatesJobTest < ActiveJob::TestCase
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

    harvester = Minitest::Mock.new
    harvester.expect(:call, lazy_candidate_proxy)

    Digitalnz::Harvester.stub(:new, ->(*) { harvester }) do
      assert_enqueued_with(job: ColouriseCandidateJob) do
        assert_equal 1, HarvestCandidatesJob.perform_now(target: 1)
      end
    end

    harvester.verify
  end

  private

  def build_harvested_candidate
    source = create_source_item(digitalnz_id: "fresh", dedupe_key: "fresh")
    candidate = source.candidates.create!(status: "pending_colour")
    attach_fixture_image(candidate)
    candidate
  end

  def lazy_candidate_proxy
    test_case = self
    candidate = nil
    Object.new.tap do |proxy|
      proxy.define_singleton_method(:id) do
        candidate ||= test_case.send(:build_harvested_candidate)
        candidate.id
      end
    end
  end
end
