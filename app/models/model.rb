class Model < RubyLLM::ActiveRecord::Model
  # Avoid STI: ruby_llm_models has no type column.
  self.inheritance_column = nil

  scope :preferred_for_colourise, -> { where(preferred_for_colourise: true) }
  scope :image_capable, -> {
    where(
      "EXISTS (SELECT 1 FROM json_each(#{table_name}.modalities, '$.output') WHERE json_each.value = ?)",
      "image"
    )
  }
  scope :openrouter, -> { where(provider: "openrouter") }

  def image_output?
    Array(modalities&.dig("output")).include?("image")
  end
end
