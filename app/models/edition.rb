class Edition < ApplicationRecord
  STATES = %w[scheduled published failed].freeze

  belongs_to :variant
  has_one :candidate, through: :variant
  has_one :source_item, through: :candidate
  has_many :deliveries, dependent: :destroy

  validates :publish_on, presence: true, uniqueness: true
  validates :state, inclusion: { in: STATES }

  scope :scheduled, -> { where(state: "scheduled") }
  scope :published, -> { where(state: "published") }
  scope :upcoming, -> { scheduled.where("publish_on >= ?", Date.current).order(:publish_on) }
  scope :past, -> { published.where("publish_on < ?", Date.current).order(publish_on: :desc) }

  def self.for_date(date)
    find_by(publish_on: date)
  end

  def self.today
    for_date(Time.zone.today)
  end

  def self.next_free_publish_on(from: Time.zone.tomorrow)
    date = from.to_date
    occupied = where("publish_on >= ?", date).pluck(:publish_on).to_set
    date += 1.day while occupied.include?(date)
    date
  end

  def self.approved_runway_days
    upcoming.count
  end

  def publish!
    update!(state: "published", published_at: Time.current)
  end

  def fail!(message = nil)
    update!(state: "failed", admin_note: [ admin_note, message ].compact.join("\n").presence)
  end

  def to_param
    publish_on.iso8601
  end
end
