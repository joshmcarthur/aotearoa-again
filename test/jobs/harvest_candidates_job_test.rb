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

  test "tops up pending_review without enqueueing colourise" do
    Digitalnz::Harvester.stub(:new, ->(*_, **_) { on_demand_harvester }) do
      assert_no_enqueued_jobs(only: ColouriseCandidateJob) do
        assert_equal 1, HarvestCandidatesJob.perform_now(target: 1)
      end
    end
  end

  test "does not count ready candidates toward the harvest target" do
    ready_source = create_source_item(digitalnz_id: "ready-1", dedupe_key: "ready-1")
    ready_source.candidates.create!(status: "ready")

    Digitalnz::Harvester.stub(:new, ->(*_, **_) { on_demand_harvester }) do
      assert_equal 1, HarvestCandidatesJob.perform_now(target: 1)
    end
  end

  test "stops when pending_review already meets the target" do
    source = create_source_item
    source.candidates.create!(status: "pending_review")

    Digitalnz::Harvester.stub(:new, ->(*_, **_) { flunk "should not harvest" }) do
      assert_equal 0, HarvestCandidatesJob.perform_now(target: 1)
    end
  end

  test "continues after an empty harvest" do
    calls = 0
    test_case = self
    harvester = sequenced_harvester do
      calls += 1
      calls == 1 ? nil : test_case.send(:build_harvested_candidate)
    end

    Digitalnz::Harvester.stub(:new, ->(*_, **_) { harvester }) do
      assert_equal 1, HarvestCandidatesJob.perform_now(target: 1)
    end
    assert_equal 2, calls
  end

  test "does not count a rate limit as an empty harvest" do
    calls = 0
    test_case = self
    harvester = sequenced_harvester do
      calls += 1
      raise Digitalnz::Client::RateLimited, "blocked" if calls <= 6

      test_case.send(:build_harvested_candidate)
    end

    Digitalnz::Harvester.stub(:new, ->(*_, **_) { harvester }) do
      assert_equal 1, HarvestCandidatesJob.perform_now(target: 1)
    end
    assert_equal 7, calls
  end

  test "stops after six empty harvests" do
    calls = 0
    harvester = sequenced_harvester do
      calls += 1
      nil
    end

    Digitalnz::Harvester.stub(:new, ->(*_, **_) { harvester }) do
      assert_equal 0, HarvestCandidatesJob.perform_now(target: 30)
    end
    assert_equal 6, calls
  end

  private

  def build_harvested_candidate
    suffix = SecureRandom.hex(4)
    source = create_source_item(digitalnz_id: "fresh-#{suffix}", dedupe_key: "fresh-#{suffix}")
    candidate = source.candidates.create!(status: "pending_review")
    attach_fixture_image(candidate)
    candidate
  end

  def on_demand_harvester
    test_case = self
    Object.new.tap do |harvester|
      harvester.define_singleton_method(:call) { test_case.send(:build_harvested_candidate) }
    end
  end

  def sequenced_harvester(&block)
    Object.new.tap do |harvester|
      harvester.define_singleton_method(:call, &block)
    end
  end
end
