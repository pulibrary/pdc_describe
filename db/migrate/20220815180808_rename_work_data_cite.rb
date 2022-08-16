class RenameWorkDataCite < ActiveRecord::Migration[6.1]
  def change
    rename_column :works, :data_cite, :metadata
    remove_column :works, :datacite_xml
  end
end
