class AddEmailMessagesEnabledToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :email_messages_enabled, :boolean, default: true
  end
end
