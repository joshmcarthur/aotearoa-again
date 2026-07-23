class ShareLink < ApplicationRecord
  belongs_to :variant

  validates :code, presence: true, uniqueness: true

  before_validation :assign_code, on: :create

  def path
    "/s/#{code}"
  end

  def url
    Rails.application.routes.url_helpers.share_link_url(
      code,
      host: AppConfig.app_host,
      protocol: AppConfig.protocol
    )
  end

  private

  def assign_code
    return if code.present?

    10.times do
      candidate = SecureRandom.urlsafe_base64(8)
      unless self.class.exists?(code: candidate)
        self.code = candidate
        return
      end
    end

    raise "Unable to generate unique share link code"
  end
end
