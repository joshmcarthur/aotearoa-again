class Delivery < ApplicationRecord
  CHANNELS = %w[web email instagram instagram_reel facebook].freeze
  STATUSES = %w[pending succeeded failed skipped].freeze
  JOBS = {
    "web" => DeliverWebJob,
    "email" => DeliverEmailJob,
    "instagram" => DeliverInstagramJob,
    "instagram_reel" => DeliverInstagramReelJob,
    "facebook" => DeliverFacebookJob
  }.freeze

  belongs_to :edition

  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :channel, uniqueness: { scope: :edition_id }

  scope :failed, -> { where(status: "failed") }

  def job_class
    JOBS.fetch(channel)
  end

  def enqueue!
    job_class.perform_later(edition_id)
  end

  def applicable?
    case channel
    when "web", "email"
      true
    when "instagram", "instagram_reel"
      AppConfig.instagram_configured? && edition.source_item.commercial_use?
    when "facebook"
      AppConfig.facebook_configured? && edition.source_item.commercial_use?
    else
      false
    end
  end

  def succeed!(external_id: nil)
    update!(
      status: "succeeded",
      external_id: external_id.presence || self.external_id,
      delivered_at: Time.current,
      error_message: nil,
      attempts: attempts + 1
    )
  end

  def fail!(message)
    update!(
      status: "failed",
      error_message: message,
      attempts: attempts + 1
    )
  end
end
