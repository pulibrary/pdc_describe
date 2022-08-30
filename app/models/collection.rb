# frozen_string_literal: true

class Collection < ApplicationRecord
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
    UserCollection.where(collection_id: id, role: "ADMIN").map(&:user)
  end

  def super_administrators
    User.with_role(:super_admin)
  end

  def submitters
    UserCollection.where(collection_id: id, role: "SUBMITTER").map(&:user)
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
