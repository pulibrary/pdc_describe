class AddCodeConstrainToCollection < ActiveRecord::Migration[6.1]
  def change
    add_index :collections, :code, unique: true
  end
end
