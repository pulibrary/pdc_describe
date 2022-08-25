class WorkRemoveDoiArk < ActiveRecord::Migration[6.1]
  def change
    remove_column :works, :doi
    remove_column :works, :ark
  end
end
