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
      EnsureEditionDeliveriesJob.perform_now(edition.id)
      ComposeShareVideoJob.perform_later(edition.variant_id)
      edition
    end

    private

    def existing_edition
      @candidate.editions.first
    end

    def schedule_edition
      Edition.create!(
        variant: @variant,
        publish_on: Edition.next_free_publish_on,
        state: "scheduled"
      )
    end
  end
end
