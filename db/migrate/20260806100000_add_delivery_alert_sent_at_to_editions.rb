class RemoveWebDeliveries < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      DELETE FROM deliveries WHERE channel = 'web'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
