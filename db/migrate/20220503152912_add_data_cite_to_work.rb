class AddDataCiteToWork < ActiveRecord::Migration[6.1]
  def change
    add_column :works, :data_cite, :json
  end
end
