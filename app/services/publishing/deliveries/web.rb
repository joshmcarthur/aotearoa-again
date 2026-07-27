module Publishing
  module Deliveries
    class Web < Base
      def self.channel = "web"

      def call
        delivery = find_or_create_delivery
        return if delivery.status == "succeeded"

        delivery.succeed!
      end
    end
  end
end
