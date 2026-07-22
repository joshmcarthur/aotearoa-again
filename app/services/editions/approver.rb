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
        edition = Edition.create!(
          variant: @variant,
          publish_on: Edition.next_free_publish_on,
          state: "scheduled"
        )
        edition.deliveries.create!(channel: "web", status: "pending")
        edition.deliveries.create!(channel: "email", status: "pending")
        edition
      end
    end
  end
end
