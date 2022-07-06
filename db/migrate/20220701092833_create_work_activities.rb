class CreateWorkActivities < ActiveRecord::Migration[6.1]
  def change
    create_table :work_activities do |t|
      t.text :message
      t.string :activity_type
      t.integer :work_id

      t.timestamps
    end

    add_foreign_key :work_activities, :works
  end
end
