class AddColumnDoiToDataset < ActiveRecord::Migration[6.1]
  def change
    add_column :datasets, :doi, :string
  end
end
