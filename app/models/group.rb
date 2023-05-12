# frozen_string_literal: true

class Group < Collection
  self.table_name = "collections"
  resourcify

  def administrators
    User.with_role(:group_admin, self)
  end

  ##
  # The current user adds a new admin user to a collection.
  # For use in the UI - we need to check whether the current_user
  # has the right permissions to add someone as an admin_user.
  # @param [User] current_user - the currently logged in user
  # @param [User] admin_user - the user who will be granted admin rights on this collection
  def add_administrator(current_user, admin_user)
    if current_user.has_role?(:super_admin) || current_user.has_role?(:group_admin, self)
      if admin_user.has_role? :group_admin, self
        errors.add(:admin, "User has already been added")
      else
        errors.delete(:admin)
        admin_user.add_role :group_admin, self
      end
    else
      errors.add(:admin, "Unauthorized")
    end
  end

  def add_submitter(current_user, additional_user)
    if current_user.has_role?(:super_admin) || current_user.has_role?(:group_admin, self)
      return if (self == additional_user.default_group) && additional_user.just_created

      if additional_user.has_role? :submitter, self
        errors.add(:submitter, "User has already been added")
      else
        errors.delete(:submitter)
        additional_user.add_role :submitter, self
      end
    else
      errors.add(:submitter, "Unauthorized")
    end
  end

  def delete_permission(current_user, removed_user)
    if current_user.has_role?(:super_admin) || current_user.has_role?(:group_admin, self)
      if removed_user.nil?
        errors.add(:delete_permission, "User was not found")
      elsif removed_user == current_user
        errors.add(:delete_permission, "Cannot remove yourself from a collection. Contact a super-admin for help.")
      else
        errors.delete(:delete_permission)
        removed_user.remove_role :group_admin, self
        removed_user.remove_role :submitter, self
      end
    else
      errors.add(:delete_permission, "Unauthorized")
    end
  end
end
