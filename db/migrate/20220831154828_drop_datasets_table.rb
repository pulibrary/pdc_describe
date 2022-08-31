class DropDatasetsTable < ActiveRecord::Migration[6.1]
  def up
    drop_table :datasets
  end
  def down
    # https://stackoverflow.com/a/7779954/446681
    raise ActiveRecord::IrreversibleMigration
  end
end
