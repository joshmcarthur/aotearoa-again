class SourceItem < ApplicationRecord
  has_many :candidates, dependent: :restrict_with_exception

  validates :digitalnz_id, :title, :record_url, :dedupe_key, presence: true
  validates :digitalnz_id, :dedupe_key, uniqueness: true

  scope :active, -> { where(discarded_at: nil) }

  def discarded?
    discarded_at.present?
  end

  def discard!
    update!(discarded_at: Time.current)
  end

  # DigitalNZ "Use commercially" — NatLib free-download / Meta-upload-eligible subset.
  def commercial_use?
    Array(usage_flags).any? { |flag| flag.to_s.casecmp?("Use commercially") }
  end
end
