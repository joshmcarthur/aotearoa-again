module Colourisers
  class ModelList
    VARIANT_COUNT = 2

    def self.for_candidate
      preferred = Model.preferred_for_colourise.openrouter.to_a
      return preferred if preferred.size >= VARIANT_COUNT
      return preferred * VARIANT_COUNT if preferred.size == 1

      fallback = Model.openrouter.image_capable.order(:name).limit(VARIANT_COUNT).to_a
      return fallback if fallback.any?

      raise "No preferred or image-capable OpenRouter models found. Run Model.refresh! and mark preferred_for_colourise."
    end
  end
end
