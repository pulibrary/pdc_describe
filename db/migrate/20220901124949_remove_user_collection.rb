class RemoveUserCollection < ActiveRecord::Migration[6.1]
  def change
    drop_table :user_collections
  end
end
