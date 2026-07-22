class HarvestCandidatesJob < ApplicationJob
  queue_as :default

  def perform(target: AppConfig.harvest_pipeline_target)
    created = 0
    while Candidate.ready_or_in_pipeline.count < target
      candidate = Digitalnz::Harvester.new.call
      break unless candidate

      created += 1
      ColouriseCandidateJob.perform_later(candidate.id)
    end
    created
  end
end
