class Model < ApplicationRecord
  acts_as_model

  has_many :variants, dependent: :restrict_with_exception

  scope :preferred_for_colourise, -> { where(preferred_for_colourise: true) }
  scope :image_capable, -> {
    where(
      "EXISTS (SELECT 1 FROM json_each(models.modalities, '$.output') WHERE json_each.value = ?)",
      "image"
    )
  }
  scope :openrouter, -> { where(provider: "openrouter") }

  def image_output?
    Array(modalities&.dig("output")).include?("image")
  end
end
