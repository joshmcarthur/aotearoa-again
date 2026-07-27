class Variant < ApplicationRecord
  belongs_to :candidate
  belongs_to :model
  has_one :edition, dependent: :restrict_with_exception
  has_one :share_link, dependent: :destroy
  has_one_attached :colourised_image
  has_one_attached :composite_image
  has_one_attached :share_image
  has_one_attached :share_video

  validates :prompt, presence: true

  scope :chosen, -> { where(chosen: true) }

  def choose!
    transaction do
      candidate.variants.where.not(id: id).update_all(chosen: false)
      update!(chosen: true)
    end
  end

  # Branded composite for OG / Atom / email / Instagram.
  def distribution_image
    share_image.attached? ? share_image : colourised_image
  end

  # Unbranded diagonal composite for archive thumbs.
  def archive_image
    composite_image.attached? ? composite_image : colourised_image
  end
end
