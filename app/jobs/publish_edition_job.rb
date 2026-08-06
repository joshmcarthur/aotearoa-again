class PublishEditionJob < ApplicationJob
  queue_as :default

  def perform(date = Time.zone.today)
    edition = Edition.scheduled.find_by(publish_on: date)
    return unless edition

    edition.with_lock do
      edition.reload
      return unless edition.state == "scheduled"

      edition.publish!
    end

    edition.deliveries.where(status: "pending").each(&:enqueue!)
  end
end
