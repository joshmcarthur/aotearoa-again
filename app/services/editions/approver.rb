module Editions
  class Approver
    def initialize(candidate, variant:)
      @candidate = candidate
      @variant = variant
    end

    def call
      raise ArgumentError, "Variant does not belong to candidate" unless @variant.candidate_id == @candidate.id

      edition = Edition.transaction do
        @variant.choose!
        if (edition = existing_edition)
          edition.update!(variant: @variant)
          edition
        else
          schedule_edition
        end
      end
      ComposeShareVideoJob.perform_later(edition.variant_id)
      edition
    end

    private

    def existing_edition
      @candidate.editions.first
    end

    def schedule_edition
      edition = Edition.create!(
        variant: @variant,
        publish_on: Edition.next_free_publish_on,
        state: "scheduled"
      )
      edition.deliveries.create!(channel: "web", status: "pending")
      edition.deliveries.create!(channel: "email", status: "pending")
      if instagram_delivery?
        edition.deliveries.create!(channel: "instagram", status: "pending")
        edition.deliveries.create!(channel: "instagram_reel", status: "pending")
      end
      if facebook_delivery?
        edition.deliveries.create!(channel: "facebook", status: "pending")
      end
      edition
    end

    def instagram_delivery?
      AppConfig.instagram_configured? && @candidate.source_item.commercial_use?
    end

    def facebook_delivery?
      AppConfig.facebook_configured? && @candidate.source_item.commercial_use?
    end
  end
end
