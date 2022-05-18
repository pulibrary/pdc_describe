class AddDatasetFieldsToWork < ActiveRecord::Migration[6.1]
  def change
    add_column :works, :profile, :string
    add_column :works, :ark, :string
    add_column :works, :doi, :string
  end
end
