module Publishing
  class Orchestrator
    DELIVERERS = [
      Deliveries::Web,
      Deliveries::Email,
      Deliveries::Instagram,
      Deliveries::Facebook
    ].freeze

    def initialize(edition, buttondown: ButtondownClient.new, meta: nil)
      @edition = edition
      @buttondown = buttondown
      @meta = meta
    end

    def call
      DELIVERERS.each do |deliverer|
        deliverer.new(@edition, meta: meta_client, buttondown: @buttondown).call
      end

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

    def meta_client
      @meta ||= Meta::Client.new
    end
  end
end
