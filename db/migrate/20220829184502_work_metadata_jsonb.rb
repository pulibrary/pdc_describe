class WorkMetadataJsonb < ActiveRecord::Migration[6.1]
  def up
    change_table :works do |t|
      t.change :metadata, 'jsonb'
    end
  end

  def down
    change_table :works do |t|
      t.change :metadata, 'json'
    end
  end
end
