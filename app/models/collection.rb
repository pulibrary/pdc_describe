# frozen_string_literal: true

# rubocop:disable Style/NumericPredicate
class Collection < ApplicationRecord
  def self.create_defaults
    return if Collection.count > 0
    Rails.logger.info "Creating default Collections"
    Collection.create(title: "Research Data", code: "RD")
    Collection.create(title: "Princeton Plasma Physics Laboratory ", code: "PPPL")
    Collection.create(title: "Electronic Theses and Dissertations", code: "ETD")
    Collection.create(title: "Library Resources", code: "LIB")
  end

  def self.default
    Collection.where(code: "RD").first
  end

  def self.default_for_department(department_number)
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
# rubocop:enable Style/NumericPredicate
