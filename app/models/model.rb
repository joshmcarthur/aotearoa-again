class Model < RubyLLM::ActiveRecord::Model
  # Application colourise settings live on RubyLLM's registry table. 2.0 owns
  # the row; we subclass so preferred_for_colourise and Variant stay queryable.
  self.inheritance_column = nil

  has_many :variants, inverse_of: :model

  scope :preferred_for_colourise, -> { where(preferred_for_colourise: true) }
  scope :image_capable, -> {
    where(
      "EXISTS (SELECT 1 FROM json_each(#{table_name}.modalities, '$.output') WHERE json_each.value = ?)",
      "image"
    )
  }
  scope :openrouter, -> { where(provider: "openrouter") }

  def image_output?
    Array(modalities_hash["output"]).include?("image")
  end

  private

  def modalities_hash
    value = modalities
    value.respond_to?(:with_indifferent_access) ? value.with_indifferent_access : {}
  end
end
