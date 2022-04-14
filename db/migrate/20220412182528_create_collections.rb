class CreateCollections < ActiveRecord::Migration[6.1]
  def change
    create_table :collections do |t|
      t.string :title
      t.text :description
      t.string :code
      t.timestamps
    end
  end
end
