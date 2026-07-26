class AddMetaUploadEligibleToSourceItems < ActiveRecord::Migration[8.1]
  def change
    add_column :source_items, :meta_upload_eligible, :boolean, null: false, default: false
  end
end
