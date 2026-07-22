preferred_ids = %w[
  google/gemini-3.1-flash-image
  google/gemini-3.1-flash-lite-image
]

Model.transaction do
  Model.where(preferred_for_colourise: true).update_all(preferred_for_colourise: false)
  Model.where(provider: "openrouter", model_id: preferred_ids).find_each do |model|
    model.update!(preferred_for_colourise: true)
  end
end

missing = preferred_ids - Model.preferred_for_colourise.pluck(:model_id)
warn "Missing preferred colourise models (run Model.refresh!): #{missing.join(", ")}" if missing.any?

puts "Preferred colourise models: #{Model.preferred_for_colourise.order(:model_id).pluck(:model_id).join(", ")}"
