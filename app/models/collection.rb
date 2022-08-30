# frozen_string_literal: true

class Collection < ApplicationRecord
  resourcify

  validate do |collection|
    if collection.title.blank?
      collection.errors.add :base, "Title cannot be empty"
    end
  end

  def default_admins_list
    return [] if code.blank?
    key = code.downcase.to_sym
    Rails.configuration.collection_defaults.dig(key, :admin) || []
  end

  def default_submitters_list
    key = code.downcase.to_sym
    Rails.configuration.collection_defaults.dig(key, :submit) || []
  end

  def administrators
    User.with_role(:collection_admin, self)
  end

  def super_administrators
    User.with_role(:super_admin)
  end

  def add_administrator(current_user, admin_user)
    if current_user.has_role?(:super_admin) || current_user.has_role?(:collection_admin, self)
      if admin_user.has_role? :collection_admin, self
        errors.add(:admin, "User has already been added")
      else
        errors.delete(:admin)
        admin_user.add_role :collection_admin, self
      end
    else
      errors.add(:admin, "Unauthorized")
    end
  end

  def add_submitter(current_user, additional_user)
    if current_user.has_role?(:super_admin) || current_user.has_role?(:collection_admin, self)
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
    if current_user.has_role?(:super_admin) || current_user.has_role?(:collection_admin, self)
      if removed_user.nil?
        errors.add(:delete_permission, "User was not found")
      elsif removed_user == current_user
        errors.add(:delete_permission, "Cannot remove yourself from a collection. Contact a super-admin for help.")
      else
        errors.delete(:delete_permission)
        removed_user.remove_role :collection_admin, self
        removed_user.remove_role :submitter, self
      end
    else
      errors.add(:delete_permission, "Unauthorized")
    end
  end

  def submitters
    User.with_role(:submitter, self)
  end

  def self.create_defaults
    return if Collection.count > 0
    Rails.logger.info "Creating default Collections"
    Collection.create(title: "Research Data", code: "RD")
    Collection.create(title: "Princeton Plasma Physics Laboratory", code: "PPPL")
  end

  # Returns the default collection.
  # Used when we don't have anything else to determine a more specific collection for a user.
  def self.default
    create_defaults
    research_data
  end

  # Returns the default collection for a given department number.
  # Reference: https://docs.google.com/spreadsheets/d/1_Elxs3Ex-2wCbbKUzD4ii3k16zx36sYf/edit#gid=1484576831
  def self.default_for_department(department_number)
    if department_number.present? && department_number >= "31000" && department_number <= "31026"
      plasma_laboratory
    else
      default
    end
  end

  def self.research_data
    create_defaults
    Collection.where(code: "RD").first
  end

  def self.plasma_laboratory
    create_defaults
    Collection.where(code: "PPPL").first
  end
end
