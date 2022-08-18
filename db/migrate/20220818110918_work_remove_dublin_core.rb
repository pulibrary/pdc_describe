class WorkRemoveDublinCore < ActiveRecord::Migration[6.1]
    def change
      remove_column :works, :dublin_core
    end
  end
