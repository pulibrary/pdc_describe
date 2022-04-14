class AddDefaultCollectionToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :default_collection_id, :integer
    add_foreign_key :users, :collections, column: :default_collection_id
  end
end
