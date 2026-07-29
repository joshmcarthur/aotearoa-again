class PublishEditionJob < ApplicationJob
  queue_as :default

  def perform(date = Time.zone.today)
    edition = Edition.scheduled.find_by(publish_on: date)
    return unless edition

    edition.deliveries.each(&:enqueue!)
  end
end
