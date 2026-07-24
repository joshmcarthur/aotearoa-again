class Candidate < ApplicationRecord
  STATUSES = %w[pending_colour colouring ready rejected].freeze

  belongs_to :source_item
  has_many :variants, dependent: :destroy
  has_many :editions, through: :variants
  has_one_attached :original_image

  validates :status, inclusion: { in: STATUSES }

  scope :pending_colour, -> { where(status: "pending_colour") }
  scope :ready, -> { where(status: "ready") }
  scope :in_pipeline, -> { where(status: %w[pending_colour colouring ready]) }
  scope :ready_or_in_pipeline, -> { in_pipeline }

  def mark_colouring!
    update!(status: "colouring")
  end

  def mark_ready!
    update!(status: "ready")
  end

  def reject!(reason: nil)
    update!(status: "rejected", rejection_reason: reason)
  end

  def review_history
    Candidates::ReviewHistory.new(self)
  end
end
