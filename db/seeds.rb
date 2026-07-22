preferred_ids = %w[
  google/gemini-3.1-flash-image-preview
  google/gemini-2.5-flash-image
]

Model.where(provider: "openrouter", model_id: preferred_ids).find_each do |model|
  model.update!(preferred_for_colourise: true)
end

puts "Preferred colourise models: #{Model.preferred_for_colourise.pluck(:model_id).join(", ")}"
