class RemoveCreatedByUserFromDataset < ActiveRecord::Migration[6.1]
  def change
    remove_column :datasets, :created_by_user_id, :integer
  end
end
