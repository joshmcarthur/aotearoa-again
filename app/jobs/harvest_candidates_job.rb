class HarvestCandidatesJob < ApplicationJob
  queue_as :default

  MAX_CONSECUTIVE_MISSES = 6

  def perform(target: AppConfig.harvest_pipeline_target)
    created = 0
    misses = 0
    selector = Digitalnz::RandomSelector.new

    while Candidate.pending_review.count < target
      harvested = harvest_one(selector)
      next if harvested == :rate_limited

      if harvested
        created += 1
        misses = 0
      else
        misses += 1
        break if misses >= MAX_CONSECUTIVE_MISSES
      end
    end

    created
  end

  private

  def harvest_one(selector)
    Digitalnz::Harvester.new(selector: selector).call
  rescue Digitalnz::Client::RateLimited
    :rate_limited
  end
end
