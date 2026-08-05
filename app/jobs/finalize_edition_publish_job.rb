class FinalizeEditionPublishJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(edition_id)
    edition = Edition.find(edition_id)

    return unless edition.deliveries_terminal?

    AdminMailer.delivery_failed(edition).deliver_later if edition.deliveries.failed.exists?
  end
end
