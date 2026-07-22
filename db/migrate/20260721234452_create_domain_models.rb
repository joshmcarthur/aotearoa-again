class CreateDomainModels < ActiveRecord::Migration[8.1]
  def change
    create_table :source_items do |t|
      t.string :digitalnz_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :display_date
      t.integer :year
      t.string :placename
      t.string :creator
      t.string :content_partner
      t.text :rights_text
      t.jsonb :usage_flags, null: false, default: []
      t.string :record_url, null: false
      t.string :image_url
      t.string :dedupe_key, null: false
      t.jsonb :raw_metadata, null: false, default: {}
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :source_items, :digitalnz_id, unique: true
    add_index :source_items, :dedupe_key, unique: true
    add_index :source_items, :discarded_at

    create_table :candidates do |t|
      t.references :source_item, null: false, foreign_key: true
      t.string :status, null: false, default: "pending_colour"
      t.text :rejection_reason

      t.timestamps
    end
    add_index :candidates, :status

    create_table :variants do |t|
      t.references :candidate, null: false, foreign_key: true
      t.references :model, null: false, foreign_key: true
      t.text :prompt, null: false
      t.boolean :chosen, null: false, default: false

      t.timestamps
    end
    add_index :variants, [ :candidate_id, :chosen ]

    create_table :editions do |t|
      t.references :variant, null: false, foreign_key: true
      t.date :publish_on, null: false
      t.string :state, null: false, default: "scheduled"
      t.text :admin_note
      t.datetime :published_at

      t.timestamps
    end
    add_index :editions, :publish_on, unique: true
    add_index :editions, :state

    create_table :deliveries do |t|
      t.references :edition, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :status, null: false, default: "pending"
      t.string :external_id
      t.text :error_message
      t.integer :attempts, null: false, default: 0
      t.datetime :delivered_at

      t.timestamps
    end
    add_index :deliveries, [ :edition_id, :channel ], unique: true
  end
end
