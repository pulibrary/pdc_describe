class CreateWorkActivityNotifications < ActiveRecord::Migration[6.1]
    def change
      create_table :work_activity_notifications do |t|
        t.integer :work_activity_id
        t.integer :user_id
        t.datetime :read_at
        t.timestamps
      end

      add_foreign_key :work_activity_notifications, :work_activities
      add_foreign_key :work_activity_notifications, :users
    end
  end
