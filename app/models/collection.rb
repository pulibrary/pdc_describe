# frozen_string_literal: true

class Collection < ApplicationRecord
  resourcify

  # CollectionOptions model extensible options set for Collections and Users
  has_many :collection_options, dependent: :destroy
  has_many :collection_messaging_options, -> { where(option_type: CollectionOption::EMAIL_MESSAGES) }, class_name: "CollectionOption", dependent: :destroy

  has_many :users_with_options, through: :collection_options, source: :user
  has_many :users_with_messaging, through: :collection_messaging_options, source: :user

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

  def super_administrators
    User.with_role(:super_admin)
  end

  def datasets
    Work.where(collection_id: id)
  end

  def submitters
    User.with_role(:submitter, self)
  end

  # Permit a User to receive notification messages for members of this Collection
  # @param user [User]
  def enable_messages_for(user:)
    raise(ArgumentError, "User #{user.uid} is not an administrator for this collection #{title}") unless user.can_admin?(self)
    collection_messaging_options << CollectionOption.new(option_type: CollectionOption::EMAIL_MESSAGES, group: self, user: user)
  end

  # Disable a User from receiving notification messages for members of this Collection
  # @param user [User]
  def disable_messages_for(user:)
    raise(ArgumentError, "User #{user.uid} is not an administrator for this collection #{title}") unless user.can_admin?(self)
    users_with_messaging.destroy(user)
  end

  # Returns true if a given user has notification e-mails enabled for this collection
  # @param user [User]
  # @return [Boolean]
  def messages_enabled_for?(user:)
    found = users_with_messaging.find_by(id: user.id)

    found.present?
  end

  def self.create_defaults
    return if count > 0
    Rails.logger.info "Creating default Collections"
    create(title: "Research Data", code: "RD")
    create(title: "Princeton Plasma Physics Laboratory", code: "PPPL")
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
    where(code: "RD").first
  end

  def self.plasma_laboratory
    create_defaults
    where(code: "PPPL").first
  end
end
