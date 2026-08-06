class NotifyDeliveryFailureJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(delivery_id) { delivery_id }, on_conflict: :discard

  discard_on ActiveRecord::RecordNotFound

  def perform(delivery_id)
    delivery = Delivery.find(delivery_id)
    return unless delivery.edition.state == "published"
    return unless delivery.status == "failed"

    AdminMailer.delivery_failed(delivery).deliver_now
  end
end
