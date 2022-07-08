
class AddCreatedByUserIdToWorkActivities < ActiveRecord::Migration[6.1]
    def change
      add_column :work_activities, :created_by_user_id, :integer
      add_foreign_key :work_activities, :users, column: :created_by_user_id
    end
  end
