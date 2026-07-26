module Publishing
  class Orchestrator
    def initialize(edition, buttondown: ButtondownClient.new, instagram: nil)
      @edition = edition
      @buttondown = buttondown
      @instagram = instagram
    end

    def call
      deliver_web
      deliver_email
      deliver_instagram
      if @edition.deliveries.reload.all? { |d| d.status == "succeeded" }
        @edition.publish!
      else
        @edition.fail!("One or more deliveries failed")
        AdminMailer.delivery_failed(@edition).deliver_later
      end
      @edition
    end

    private

    def deliver_web
      delivery = @edition.deliveries.find_or_create_by!(channel: "web")
      return if delivery.status == "succeeded"

      delivery.succeed!
    end

    def deliver_email
      delivery = @edition.deliveries.find_or_create_by!(channel: "email")
      return if delivery.status == "succeeded" && delivery.external_id.present?

      copy = Editions::Copy.new(@edition.source_item)
      image_url = share_image_url
      unless image_url
        delivery.fail!("Share image missing")
        return
      end

      payload = @buttondown.create_and_send(
        subject: copy.title,
        body: copy.email_markdown(edition_url: public_edition_url, image_url: image_url)
      )
      delivery.succeed!(external_id: payload["id"].to_s)
    rescue ButtondownClient::Error => e
      delivery.fail!(e.message)
    end

    def deliver_instagram
      unless AppConfig.instagram_configured?
        skip_unconfigured_instagram_delivery
        return
      end

      delivery = @edition.deliveries.find_or_create_by!(channel: "instagram")
      return if delivery.status == "succeeded" && delivery.external_id.present?

      image_url = share_image_url
      unless image_url
        delivery.fail!("Share image missing")
        return
      end

      copy = Editions::Copy.new(@edition.source_item)
      media_id = instagram_client.publish_photo(
        image_url: image_url,
        caption: copy.instagram_caption(edition_url: public_edition_url),
        alt_text: copy.alt_text
      )
      delivery.succeed!(external_id: media_id.to_s)
    rescue InstagramClient::Error => e
      delivery.fail!(e.message)
    end

    def skip_unconfigured_instagram_delivery
      delivery = @edition.deliveries.find_by(channel: "instagram")
      return unless delivery
      return if delivery.status == "succeeded"

      delivery.destroy!
    end

    def instagram_client
      @instagram ||= InstagramClient.new
    end

    def public_edition_url
      Rails.application.routes.url_helpers.edition_url(
        @edition,
        host: AppConfig.app_host,
        protocol: AppConfig.protocol
      )
    end

    def share_image_url
      image = @edition.variant.distribution_image
      return unless image.attached?

      Rails.application.routes.url_helpers.edition_share_image_url(
        @edition,
        host: AppConfig.app_host,
        protocol: AppConfig.protocol
      )
    end
  end
end
