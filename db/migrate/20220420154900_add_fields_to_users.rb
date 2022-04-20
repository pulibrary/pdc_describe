class AddFieldsToUsers < ActiveRecord::Migration[6.1]
    def change
      add_column :users, :display_name, :string
      add_column :users, :full_name, :string
    end
  end
