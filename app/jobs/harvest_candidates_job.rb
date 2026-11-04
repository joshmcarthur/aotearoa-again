class HarvestCandidatesJob < ApplicationJob
  queue_as :default

  MAX_CONSECUTIVE_MISSES = 6
  PEOPLE_SHARE = 3

  def perform(target: AppConfig.harvest_pipeline_target)
    created = 0
    misses = 0
    selector = Digitalnz::RandomSelector.new

    while Candidate.pending_review.count < target
      harvested = harvest_one(selector, target)
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

  def harvest_one(selector, target)
    Digitalnz::Harvester.new(selector: selector, allow_people: allow_people?(target)).call
  rescue Digitalnz::Client::RateLimited
    :rate_limited
  end

  def allow_people?(target)
    people_pending_count < (target / PEOPLE_SHARE)
  end

  def people_pending_count
    Candidate.pending_review.includes(:source_item).count do |candidate|
      Digitalnz::HarvestConfig.current.people_record?(candidate.source_item.raw_metadata)
    end
  end
end
