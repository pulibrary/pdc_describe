class AddNotesToWork < ActiveRecord::Migration[6.1]
    def change
      add_column :works, :location_notes, :text
      add_column :works, :submission_notes, :text
      add_column :works, :files_location, :string
    end
  end
