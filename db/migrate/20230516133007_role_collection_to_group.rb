class RoleCollectionToGroup < ActiveRecord::Migration[6.1]
  # Please note that for some reason roles are not valid, although the system still seems to work
  # This may be related to the Collection is a parent of Group.  We may want to unwind that once the crisis is over
  def up
    Role.where(resource_type: "Collection", name: "collection_admin").each do |role|
      role.resource_type = "Group"
      role.name = "group_admin"
      role.save(validate: false)
    end
    Role.where(resource_type: "Collection").each do |role|
      role.resource_type = "Group"
      role.save(validate: false)
    end
  end

  def down
    Role.where(resource_type: "Group", name: "group_admin").each do |role|
      role.resource_type = "Collection"
      role.name = "collection_admin"
      role.save(validate: false)
    end
    Role.where(resource_type: "Group").each do |role|
      role.resource_type = "Collection"
      role.save(validate: false)
    end
  end
end
