# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Group < ApplicationRecord
  resourcify

  # GroupOptions model extensible options set for Groups and Users
  has_many :group_options, dependent: :destroy, class_name: "GroupOption"
  has_many :group_messaging_options, -> { where(option_type: GroupOption::EMAIL_MESSAGES) }, class_name: "GroupOption", dependent: :destroy

  has_many :users_with_options, through: :group_options, source: :user
  has_many :users_with_messaging, through: :group_messaging_options, source: :user

  validate do |group|
    if group.title.blank?
      group.errors.add :base, "Title cannot be empty"
    end
  end

  def default_admins_list
    return [] if code.blank?
    key = code.downcase.to_sym
    Rails.configuration.group_defaults.dig(key, :admin) || []
  end

  def default_submitters_list
    key = code.downcase.to_sym
    Rails.configuration.group_defaults.dig(key, :submit) || []
  end

  def super_administrators
    User.with_role(:super_admin)
  end

  def datasets
    Work.where(group_id: id)
  end

  def submitters
    User.with_role(:submitter, self)
  end

  # Permit a User to receive notification messages for members of this Group
  # @param user [User]
  def enable_messages_for(user:, subcommunity: nil)
    raise(ArgumentError, "User #{user.uid} is not an administrator or submitter for this group #{title}") unless user.can_admin?(self) || user.can_submit?(self)
    group = GroupOption.find_or_initialize_by(option_type: GroupOption::EMAIL_MESSAGES, user:, group: self, subcommunity:)
    group.enabled = true
    group.save
  end

  # Disable a User from receiving notification messages for members of this Group
  # @param user [User]
  def disable_messages_for(user:, subcommunity: nil)
    raise(ArgumentError, "User #{user.uid} is not an administrator or submitter for this group #{title}") unless user.can_admin?(self) || user.can_submit?(self)
    group = GroupOption.find_or_initialize_by(option_type: GroupOption::EMAIL_MESSAGES, user:, group: self, subcommunity:)
    group.enabled = false
    group.save
  end

  # Returns true if a given user has notification e-mails enabled for this Group
  # @param user [User]
  # @return [Boolean]
  def messages_enabled_for?(user:, subcommunity: nil)
    group_option = group_messaging_options.find_by(user:, group: self, subcommunity:)
    group_option ||= GroupOption.new(enabled: true)
    group_option.enabled
  end

  def self.create_defaults
    return if where(code: "RD").count > 0
    Rails.logger.info "Creating default Groups"
    create(title: "Princeton Research Data Service (PRDS)", code: "RD")
    create(title: "Princeton Plasma Physics Lab (PPPL)", code: "PPPL")
  end

  # Returns the default group.
  # Used when we don't have anything else to determine a more specific Group for a user.
  def self.default
    create_defaults
    research_data
  end

  # Returns the default group for a given department number.
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

  def administrators
    User.with_role(:group_admin, self)
  end

  ##
  # The current user adds a new admin user to a group.
  # For use in the UI - we need to check whether the current_user
  # has the right permissions to add someone as an admin_user.
  # @param [User] current_user - the currently logged in user
  # @param [User] admin_user - the user who will be granted admin rights on this group
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
        errors.add(:delete_permission, "Cannot remove yourself from a group. Contact a super-admin for help.")
      else
        errors.delete(:delete_permission)
        removed_user.remove_role :group_admin, self
        removed_user.remove_role :submitter, self
      end
    else
      errors.add(:delete_permission, "Unauthorized")
    end
  end

  def communities
    if code == "PPPL"
      ["Princeton Plasma Physics Laboratory"]
    else
      ["Princeton Neuroscience Institute", "Department of Geosciences", "Mechanical and Aerospace Engineering",
       "Astrophysical Sciences", "Civil and Environmental Engineering", "Chemical and Biological Engineering",
       "Digital Humanities", "Music and Arts", "Princeton School of Public and International Affairs"].sort
    end
  end

  # rubocop:disable Metrics/MethodLength
  def subcommunities
    values = []
    if code == "PPPL"
      values << "Spherical Torus"
      values << "Advanced Projects"
      values << "ITER and Tokamaks"
      values << "Theory"
      values << "NSTX-U"
      values << "NSTX"
      values << "Discovery Plasma Science"
      values << "Theory and Computation"
      values << "Stellarators"
      values << "PPPL Collaborations"
      values << "MAST-U"
      values << "Other Projects"
      values << "System Studies"
      values << "Applied Materials and Sustainability Sciences"

    end
    values.sort
  end
  # rubocop:enable Metrics/MethodLength

  def publisher
    if code == "PPPL"
      "Princeton Plasma Physics Laboratory, Princeton University"
    else
      "Princeton University"
    end
  end

  def default_community
    return communities.first if code == "PPPL"
  end
end
# rubocop:enable Metrics/ClassLength
