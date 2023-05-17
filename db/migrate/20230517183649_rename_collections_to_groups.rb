class RenameCollectionsToGroups < ActiveRecord::Migration[6.1]
  def up
    rename_table :collections, :groups
    rename_column :works, :collection_id, :group_id
  end

  def down
    rename_table :groups, :collections
    rename_column :works, :group_id, :collection_id
  end
end
