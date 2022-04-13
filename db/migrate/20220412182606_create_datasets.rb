class CreateDatasets < ActiveRecord::Migration[6.1]
  def change
    create_table :datasets do |t|
      t.string :title
      t.string :profile
      t.string :ark
      t.integer :created_by_user_id
      t.integer :collection_id

      t.timestamps
    end

    add_foreign_key :datasets, :collections
    add_foreign_key :datasets, :users, column: :created_by_user_id
  end
end
