class Delivery < ApplicationRecord
  CHANNELS = %w[web email instagram facebook].freeze
  STATUSES = %w[pending succeeded failed].freeze

  belongs_to :edition

  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :channel, uniqueness: { scope: :edition_id }

  scope :failed, -> { where(status: "failed") }

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
