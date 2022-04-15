class CreateUserCollections < ActiveRecord::Migration[6.1]
    def change
      create_table :user_collections do |t|
        t.string :role # submitter, approver, admin
        t.integer :user_id
        t.integer :collection_id

        t.timestamps
      end

      add_foreign_key :user_collections, :collections
      add_foreign_key :user_collections, :users
    end
  end
