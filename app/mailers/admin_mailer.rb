class AdminMailer < ApplicationMailer
  default to: -> { AppConfig.admin_alert_email }

  def runway_low(days)
    @days = days
    mail(subject: "[Aotearoa, Again] Approved runway low (#{days} days)")
  end

  def delivery_failed(edition)
    @edition = edition
    mail(subject: "[Aotearoa, Again] Delivery failed for #{edition.publish_on}")
  end
end
