class AddPreferredForColouriseToModels < ActiveRecord::Migration[8.1]
  def change
    add_column :models, :preferred_for_colourise, :boolean, null: false, default: false
    add_index :models, :preferred_for_colourise
  end
end
