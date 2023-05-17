class CollectionToGroupOptions < ActiveRecord::Migration[6.1]
  def up
    rename_column :collection_options, :collection_id, :group_id
  end
  def down
    rename_column :collection_options, :group_id, :collection_id
  end
end
