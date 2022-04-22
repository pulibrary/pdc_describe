# frozen_string_literal: true

class Collection < ApplicationRecord
  validate do |collection|
    if collection.title.blank?
      collection.errors.add :base, "Title cannot be empty"
    end
  end

  def admin_list
    if code == "PPPL"
      ["hc8719", "pp2", "pp3"]
    elsif code == "ETD"
      ["etd1", "etd2", "hc8719"]
    else
      []
    end
  end

  def submit_list
    admin_list
  end

  def self.create_defaults
    return if Collection.count > 0
    Rails.logger.info "Creating default Collections"
    Collection.create(title: "Research Data", code: "RD")
    Collection.create(title: "Princeton Plasma Physics Laboratory", code: "PPPL")
    Collection.create(title: "Electronic Theses and Dissertations", code: "ETD")
    Collection.create(title: "Library Resources", code: "LIB")
  end

  # Returns the default collection.
  # Used when we don't have anything else to determine a more specific collection for a user.
  def self.default
    create_defaults
    Collection.where(code: "RD").first
  end

  # Returns the default collection for a given department number.
  def self.default_for_department(department_number)
    create_defaults
    # Reference: https://docs.google.com/spreadsheets/d/1_Elxs3Ex-2wCbbKUzD4ii3k16zx36sYf/edit#gid=1484576831
    if department_number.nil?
      default
    elsif department_number >= "31000" && department_number <= "31026"
      Collection.where(code: "PPPL").first
    elsif department_number >= "41000" && department_number <= "41032"
      Collection.where(code: "LIB").first
    else
      default
    end
  end
end
