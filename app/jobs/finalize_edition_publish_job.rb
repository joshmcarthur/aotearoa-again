class FinalizeEditionPublishJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(edition_id)
    edition = Edition.find(edition_id)

    edition.with_lock do
      return unless edition.state == "scheduled"
      return unless edition.deliveries_terminal?

      # Publish even when some deliveries failed so successful channels stay reachable.
      edition.publish!
    end

    AdminMailer.delivery_failed(edition).deliver_later if edition.deliveries.failed.exists?
  end
end
