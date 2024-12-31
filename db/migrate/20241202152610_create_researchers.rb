class CreateResearchers < ActiveRecord::Migration[6.1]
  def change
    create_table :researchers do |t|
      t.string "first_name", null: false
      t.string "last_name", null: false
      t.string "orcid", null: false
      t.string "affiliation", null: true
      t.string "affiliation_ror", null: true
      t.string "netid", null: true

      t.timestamps
    end
  end
end
