class WorkRemoveTitle < ActiveRecord::Migration[6.1]
  def change
    remove_column :works, :title
  end
end
