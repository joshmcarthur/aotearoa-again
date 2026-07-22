class Variant < ApplicationRecord
  belongs_to :candidate
  belongs_to :model
  has_one :edition, dependent: :restrict_with_exception
  has_one_attached :colourised_image

  validates :prompt, presence: true

  scope :chosen, -> { where(chosen: true) }

  def choose!
    transaction do
      candidate.variants.where.not(id: id).update_all(chosen: false)
      update!(chosen: true)
    end
  end
end
