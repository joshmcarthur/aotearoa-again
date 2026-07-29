class DeliveryJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def self.channel
    raise NotImplementedError, "#{name} must define .channel"
  end

  # Retries transient API failures; re-enqueue manually for a failed delivery after exhaustion.
  def self.retry_delivery_on(*errors)
    retry_on(*errors, wait: :polynomially_longer, attempts: 5) do |job, error|
      edition_id = job.arguments.first
      Delivery.find_by!(edition_id: edition_id, channel: job.class.channel).fail!(error.message)
      Publishing::FinalizeEdition.enqueue_if_ready(edition_id)
    end
  end

  def perform(edition_id)
    edition = Edition.find(edition_id)
    delivery = edition.deliveries.find_or_create_by!(channel: self.class.channel)

    delivery.with_lock do
      delivery.reload
      return if already_succeeded?(delivery)
      return if delivery.status == "skipped"

      unless delivery.applicable?
        skip_delivery!(delivery)
        return
      end
    end

    deliver(edition, delivery)
  ensure
    Publishing::FinalizeEdition.enqueue_if_ready(edition_id)
  end

  private

  def deliver(edition, delivery)
    raise NotImplementedError, "#{self.class.name} must implement #deliver"
  end

  def requires_external_id?
    true
  end

  def already_succeeded?(delivery)
    return false unless delivery.status == "succeeded"
    return true unless requires_external_id?

    delivery.external_id.present?
  end

  def skip_delivery!(delivery)
    return if delivery.status.in?(%w[succeeded skipped])

    delivery.update!(status: "skipped")
  end

  def succeed_unless_done!(delivery, external_id: nil)
    delivery.with_lock do
      delivery.reload
      return if already_succeeded?(delivery)

      delivery.succeed!(external_id: external_id)
    end
  end
end
