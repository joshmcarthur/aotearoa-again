class DeliverWebJob < DeliveryJob
  def self.channel = "web"

  private

  def requires_external_id? = false

  def deliver(_edition, delivery)
    succeed_unless_done!(delivery)
  end
end
