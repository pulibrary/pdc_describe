class CreateUserMessageEnabledCollections < ActiveRecord::Migration[6.1]
  def change
    create_table :user_message_enabled_collections, id: false do |t|
      t.belongs_to :user
      t.belongs_to :collection
    end
  end
end
