module Publishing
  class NotifyDeliveryFailures
    def self.call(edition_id)
      edition = Edition.find_by(id: edition_id)
      return unless edition&.state == "published"
      return unless edition.deliveries_terminal?
      return unless edition.deliveries.failed.exists?

      edition.with_lock do
        edition.reload
        return if edition.delivery_alert_sent_at.present?

        AdminMailer.delivery_failed(edition).deliver_later
        edition.update!(delivery_alert_sent_at: Time.current)
      end
    end
  end
end
