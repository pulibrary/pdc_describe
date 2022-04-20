class CreateWorks < ActiveRecord::Migration[6.1]
    def change
      create_table :works do |t|
        t.string :title
        t.string :work_type
        t.string :state
        t.integer :collection_id
        t.integer :created_by_user_id

        t.timestamps
      end

      add_foreign_key :works, :collections
      add_foreign_key :works, :users, column: :created_by_user_id
    end
  end
