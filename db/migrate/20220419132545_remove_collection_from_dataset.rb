class RemoveCollectionFromDataset < ActiveRecord::Migration[6.1]
  def change
    remove_column :datasets, :collection_id, :integer
  end
end
