class EnsureEditionDeliveriesJob < ApplicationJob
  queue_as :default

  def perform(edition_id = nil)
    if edition_id
      ensure_for(Edition.find(edition_id))
    else
      Edition.scheduled.find_each { |edition| ensure_for(edition) }
    end
  end

  private

  def ensure_for(edition)
    Delivery::CHANNELS.each do |channel|
      delivery = edition.deliveries.find_or_initialize_by(channel: channel)
      next unless delivery.new_record?

      delivery.status = delivery.applicable? ? "pending" : "skipped"
      delivery.save!
    end
  end
end
