class HarvestCandidatesJob < ApplicationJob
  queue_as :default

  def perform(target: AppConfig.harvest_pipeline_target)
    created = 0
    while Candidate.pending_review.count < target
      break unless Digitalnz::Harvester.new.call

      created += 1
    end
    created
  end
end
