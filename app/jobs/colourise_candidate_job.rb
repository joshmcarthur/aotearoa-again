class ColouriseCandidateJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(candidate_id, model_ids: nil, replace: false)
    candidate = Candidate.find(candidate_id)
    return if candidate.status == "rejected"

    candidate.mark_colouring!
    candidate.variants.destroy_all if replace

    models = if model_ids.present?
      Model.where(id: model_ids).to_a
    else
      Colourisers::ModelList.for_candidate
    end

    colouriser = Colourisers::RubyLlmColouriser.new
    models.each do |model|
      result = colouriser.call(attachment: candidate.original_image, model: model)
      variant = candidate.variants.create!(
        model: result[:model],
        prompt: result[:prompt]
      )
      variant.colourised_image.attach(
        io: result[:io],
        filename: result[:filename],
        content_type: result[:content_type]
      )
    end

    candidate.mark_ready!
  rescue Colourisers::RubyLlmColouriser::Error => e
    candidate.update!(status: "pending_colour")
    raise e
  end
end
