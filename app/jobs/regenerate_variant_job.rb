class RegenerateVariantJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(variant_id, model_id: nil)
    variant = Variant.find(variant_id)
    candidate = variant.candidate
    return if candidate.status == "rejected"

    model = model_id.present? ? Model.find(model_id) : variant.model

    candidate.mark_colouring!

    colouriser = Colourisers::RubyLlmColouriser.new
    result = colouriser.call(attachment: candidate.original_image, model: model)

    variant.update!(model: result[:model], prompt: result[:prompt])
    variant.colourised_image.attach(
      io: result[:io],
      filename: result[:filename],
      content_type: result[:content_type]
    )

    ComposeShareImageJob.perform_later(variant.id)
    ComposeShareVideoJob.perform_later(variant.id) if variant.edition

    candidate.mark_ready!
  rescue Colourisers::RubyLlmColouriser::Error => e
    candidate.update!(status: "pending_colour")
    raise e
  end
end
