class AddDcElementsToWork < ActiveRecord::Migration[6.1]
  def change
    add_column :works, :dublin_core, :json
  end
end
