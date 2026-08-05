class AddMetadataToDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :deliveries, :metadata, :json, default: {}, null: false
  end
end
