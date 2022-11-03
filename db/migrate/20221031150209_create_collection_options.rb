class CreateCollectionOptions < ActiveRecord::Migration[6.1]
  def change
    create_table :collection_options do |t|
      t.integer :option_type
      t.integer :option_value
      t.belongs_to :collection
      t.belongs_to :user
    end
  end
end
