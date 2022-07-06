class AddCuratorToWork < ActiveRecord::Migration[6.1]
  def change
    add_column :works, :curator_user_id, :integer
    add_foreign_key :works, :users, column: :curator_user_id
  end
end
