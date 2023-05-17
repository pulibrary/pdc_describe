class RenameCollectionToGroup < ActiveRecord::Migration[6.1]
  def up
    rename_table :collection_options, :group_options
    rename_column :users, :default_collection_id, :default_group_id
  end

  def down
    rename_table :group_options, :collection_options
    rename_column :users, :default_group_id, :default_collection_id
  end
end
