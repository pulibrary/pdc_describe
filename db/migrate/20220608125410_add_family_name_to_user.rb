class AddFamilyNameToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :family_name, :string
  end
end
