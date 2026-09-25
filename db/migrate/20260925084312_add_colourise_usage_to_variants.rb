class AddColouriseUsageToVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :variants, :colourise_usage, :json, default: {}, null: false
  end
end
