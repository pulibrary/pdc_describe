class AddSentFlagToWorkActivityNotification < ActiveRecord::Migration[8.1]
  def up
    add_column :work_activity_notifications, :email_sent, :jsonb, default: {type: 'unknown'}
  end
  def down
    remove_column :work_activity_notifications, :email_sent, :jsonb
  end
end
