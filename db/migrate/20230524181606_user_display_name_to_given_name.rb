class UserDisplayNameToGivenName < ActiveRecord::Migration[6.1]
  def up
    rename_column :users, :display_name, :given_name
  end
  def down
    rename_column :users, :given_name, :display_name
  end
end
