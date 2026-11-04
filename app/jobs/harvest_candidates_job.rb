class HarvestCandidatesJob < ApplicationJob
  queue_as :default

  PEOPLE_SHARE = 3

  def perform(target: AppConfig.harvest_pipeline_target)
    created = 0
    while Candidate.pending_review.count < target
      break unless Digitalnz::Harvester.new(allow_people: allow_people?(target)).call

      created += 1
    end
    created
  end

  private

  def allow_people?(target)
    people_pending_count < (target / PEOPLE_SHARE)
  end

  def people_pending_count
    Candidate.pending_review.includes(:source_item).count do |candidate|
      Digitalnz::HarvestConfig.current.people_record?(candidate.source_item.raw_metadata)
    end
  end
end
