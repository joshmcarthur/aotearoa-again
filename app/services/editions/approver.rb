module Editions
  class Approver
    def initialize(candidate, variant:)
      @candidate = candidate
      @variant = variant
    end

    def call
      raise ArgumentError, "Variant does not belong to candidate" unless @variant.candidate_id == @candidate.id

      Edition.transaction do
        @variant.choose!
        if (edition = existing_edition)
          edition.update!(variant: @variant)
          edition
        else
          schedule_edition
        end
      end
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
      if AppConfig.instagram_configured?
        edition.deliveries.create!(channel: "instagram", status: "pending")
      end
      edition
    end
  end
end
