class CreateShareLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :share_links do |t|
      t.references :variant, null: false, foreign_key: true, index: { unique: true }
      t.string :code, null: false

      t.timestamps
    end
    add_index :share_links, :code, unique: true
  end
end
