class CreateUserWorks < ActiveRecord::Migration[6.1]
    def change
      create_table :user_works do |t|
        t.string :state
        t.integer :user_id
        t.integer :work_id

        t.timestamps
      end

      add_foreign_key :user_works, :works
      add_foreign_key :user_works, :users
    end
  end
