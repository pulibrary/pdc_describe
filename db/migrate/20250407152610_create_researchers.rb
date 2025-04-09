class CreateResearchers < ActiveRecord::Migration[6.1]
  def change
    create_table :researchers do |t|
      t.string "first_name", null: false
      t.string "last_name", null: false
      t.string "orcid", null: false

      t.timestamps
    end

    add_index :researchers, :first_name
    add_index :researchers, :last_name
    add_index :researchers, :orcid
  end
end
