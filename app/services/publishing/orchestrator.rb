module Publishing
  class Orchestrator
    DELIVERERS = [
      Deliveries::Web,
      Deliveries::Email,
      Deliveries::Instagram,
      Deliveries::Facebook
    ].freeze

    def initialize(edition, email_client: nil, instagram_client: nil, facebook_client: nil)
      @edition = edition
      @email_client = email_client
      @instagram_client = instagram_client
      @facebook_client = facebook_client
    end

    def call
      Deliveries::Web.new(@edition).call
      Deliveries::Email.new(@edition, client: @email_client).call
      Deliveries::Instagram.new(@edition, client: @instagram_client).call
      Deliveries::Facebook.new(@edition, client: @facebook_client).call

      if deliveries_ready_to_publish?
        @edition.publish!
      else
        @edition.fail!("One or more deliveries failed")
        AdminMailer.delivery_failed(@edition).deliver_later
      end
      @edition
    end

    private

    def deliveries_ready_to_publish?
      optional_channels = DELIVERERS.select(&:optional?).map(&:channel)

      @edition.deliveries.reload.all? do |delivery|
        delivery.status == "succeeded" ||
          (optional_channels.include?(delivery.channel) && delivery.status == "failed")
      end
    end
  end
end
