class AddWorkToDataset < ActiveRecord::Migration[6.1]
    def change
      add_column :datasets, :work_id, :integer
      add_foreign_key :datasets, :works
    end
  end
