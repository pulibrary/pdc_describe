class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :netid
      t.string :name
      t.string :email
      t.string :orcid
      t.boolean :super_admin

      t.timestamps
    end
  end
end
