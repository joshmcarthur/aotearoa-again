class RunwayAlertJob < ApplicationJob
  queue_as :default

  THRESHOLD = 7

  def perform
    days = Edition.approved_runway_days
    return if days >= THRESHOLD

    AdminMailer.runway_low(days).deliver_later
  end
end
