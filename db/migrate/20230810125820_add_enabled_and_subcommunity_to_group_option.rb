class AddEnabledAndSubcommunityToGroupOption < ActiveRecord::Migration[6.1]
  def up
    add_column :group_options, :enabled, 'boolean', default: true
    add_column :group_options, :subcommunity, 'string', default: nil
  end
  def down
    remove_column :group_options, :enabled, 'boolean'
    remove_column :group_options, :subcommunity, 'string'
  end
end
