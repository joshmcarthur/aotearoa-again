class AddDeliveryAlertSentAtToEditions < ActiveRecord::Migration[8.1]
  def up
    add_column :editions, :delivery_alert_sent_at, :datetime

    execute <<~SQL.squish
      DELETE FROM deliveries WHERE channel = 'web'
    SQL
  end

  def down
    remove_column :editions, :delivery_alert_sent_at
  end
end
