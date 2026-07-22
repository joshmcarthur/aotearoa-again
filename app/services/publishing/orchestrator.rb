module Publishing
  class Orchestrator
    def initialize(edition, buttondown: ButtondownClient.new)
      @edition = edition
      @buttondown = buttondown
    end

    def call
      deliver_web
      deliver_email
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
      edition_url = Rails.application.routes.url_helpers.edition_url(
        @edition,
        host: AppConfig.app_host,
        protocol: AppConfig.protocol
      )
      image_url = colourised_url

      payload = @buttondown.create_draft(
        subject: copy.title,
        body: copy.email_markdown(edition_url: edition_url, image_url: image_url)
      )
      delivery.succeed!(external_id: payload["id"].to_s)
    rescue ButtondownClient::Error => e
      delivery.fail!(e.message)
    end

    def colourised_url
      image = @edition.variant.colourised_image
      return unless image.attached?

      Rails.application.routes.url_helpers.rails_blob_url(
        image,
        host: AppConfig.app_host,
        protocol: AppConfig.protocol
      )
    end
  end
end
