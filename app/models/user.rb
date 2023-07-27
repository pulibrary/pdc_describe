# frozen_string_literal: true
require "csv"

# rubocop:disable Metrics/ClassLength
class User < ApplicationRecord
  rolify
  extend FriendlyId
  friendly_id :uid

  devise :rememberable, :omniauthable

  # GroupOptions model extensible options set for Groups and Users
  has_many :group_options, dependent: :destroy
  has_many :group_messaging_options, -> { where(option_type: GroupOption::EMAIL_MESSAGES) }, class_name: "GroupOption", dependent: :destroy

  has_many :groups_with_options, through: :group_options, source: :group
  has_many :groups_with_messaging, through: :group_messaging_options, source: :group

  after_create :assign_default_role

  attr_accessor :just_created

  validate do |user|
    user.orcid&.strip!
    if user.orcid.present? && Orcid.invalid?(user.orcid)
      user.errors.add :base, "Invalid format for ORCID"
    end
  end

  def self.from_cas(access_token)
    user = User.find_by(uid: access_token.uid)
    if user.nil?
      user = new_from_cas(access_token)
    elsif user.provider.blank?
      user.update_with_cas(access_token)
    end
    user
  end

  # Create a new user with some basic information from CAS.
  def self.new_from_cas(access_token)
    user = User.new
    user.provider = access_token.provider
    user.uid = access_token.uid # this is the netid
    user.email = access_token.extra.mail
    user.given_name = access_token.extra.givenname || access_token.uid # Harriet
    user.family_name = access_token.extra.sn || access_token.uid # Tubman
    user.full_name = access_token.extra.displayname || access_token.uid # "Harriet Tubman"
    user.default_group_id = Group.default_for_department(access_token.extra.departmentnumber)&.id
    user.save!
    user
  end

  # Updates an existing User record with some information from CAS. This is useful
  # for records created before the user ever logged in (e.g. to gran them permissions
  # to groups).
  def update_with_cas(access_token)
    self.provider = access_token.provider
    self.email = access_token.extra.mail
    self.given_name = access_token.extra.givenname || access_token.uid # Harriet
    self.family_name = access_token.extra.sn || access_token.uid # Tubman
    self.full_name = access_token.extra.displayname || access_token.uid # "Harriet Tubman"
    self.default_group_id = Group.default_for_department(access_token.extra.departmentnumber)&.id
    save!
  end

  # Creates a new user by uid. If the user already exists it returns the existing user.
  def self.new_for_uid(uid)
    user = User.find_by(uid: uid)
    if user.nil?
      user = User.new(uid: uid, email: "#{uid}@princeton.edu")
      user.save!
    end
    user
  end

  def self.new_super_admin(uid)
    user = new_for_uid(uid)
    user.add_role(:super_admin) unless user.has_role?(:super_admin)
    user.add_role(:group_admin) unless user.has_role?(:group_admin)
    user
  end

  # rubocop:disable Metrics/MethodLength
  def self.new_from_csv_params(csv_params)
    email = "#{csv_params['Net ID']}@princeton.edu"
    uid = csv_params["Net ID"]
    given_name = csv_params["First Name"]
    family_name = csv_params["Last Name"]
    full_name = "#{given_name} #{family_name}"
    orcid = csv_params["ORCID ID"]
    user = User.where(email: email).first_or_create
    params_hash = {
      email: email,
      uid: uid,
      orcid: orcid,
      full_name: (full_name if user.full_name.blank?),
      family_name: (family_name if user.family_name.blank?),
      given_name: (given_name if user.given_name.blank?)
    }.compact

    user.update(params_hash)
    Rails.logger.info "Successfully created or updated #{user.email}"
    user
  end
  # rubocop:enable Metrics/MethodLength

  def self.create_users_from_csv(csv)
    users = []
    CSV.foreach(csv, headers: true) do |row|
      next if row["Net ID"] == "N/A"
      users << new_from_csv_params(row.to_hash)
    end
    users
  end

  # Creates the default users as indicated in the super_admin config file
  # and the default administrators and submitters for each group.
  # It only creates missing records, i.e. if the records already exist it
  # will not create a duplicate. It also does _not_ remove already configured
  # access to other groups.
  def self.create_default_users
    update_super_admins

    Group.find_each do |group|
      Rails.logger.info "Setting up admins for group #{group.title}"
      group.default_admins_list.each do |uid|
        user = User.new_for_uid(uid)
        user.add_role :group_admin, group
      end

      Rails.logger.info "Setting up submitters for group #{group.title}"
      group.default_submitters_list.each do |uid|
        user = User.new_for_uid(uid)
        user.add_role :submitter, group
      end
    end
  end

  def self.update_super_admins
    Rails.logger.info "Setting super administrators"
    Rails.configuration.super_admins.each do |uid|
      new_super_admin(uid)
    end
  end

  # Returns a string with the UID (netid) for all the users.
  # We use this string to power the JavaScript @mention functionality when adding messages to works.
  def self.all_uids_string
    User.all.map { |user| '"' + user.uid + '"' }.join(", ")
  end

  ##
  # Is this user a super_admin? super_admins automatically get admin status in every
  # group, and they can make new groups.
  # @return [Boolean]
  def super_admin?
    has_role? :super_admin
  rescue => ex
    Rails.logger.error("Unexpected error checking super_admin: #{ex}")
    false
  end

  # Returns a display name that always has a value
  # This is needed because we have records in the Users table that are created automatically
  # in which the only value we have for sure its their uid (aka NetID).
  def given_name_safe
    given_name.presence || uid
  end

  def moderator?
    admin_groups.count > 0
  end

  # Returns a reference to the user's default group.
  def default_group
    if default_group_id.nil?
      Group.default
    else
      Group.find(default_group_id)
    end
  end

  # True if the user can submit datasets to the group
  def can_submit?(group)
    return true if super_admin?
    has_role?(:submitter, group)
  end

  # Returns true if the user can admin the group
  def can_admin?(group)
    return true if super_admin?
    has_role? :group_admin, group
  end

  # Returns the list of groups where the user can submit datasets
  def submitter_groups
    @submitter_groups = if super_admin?
                          Group.all.to_a
                        else
                          (Group.with_role(:submitter, self) + Group.with_role(:group_admin, self)).uniq
                        end
  end

  # Returns the list of groups where the user is an administrator
  def admin_groups
    @admin_groups ||= if super_admin?
                        Group.all.to_a
                      else
                        Group.with_role(:group_admin, self)
                      end
  end

  def submitter_or_admin_groups
    submitter_groups | admin_groups
  end

  def pending_notifications_count
    WorkActivityNotification.where(user_id: id, read_at: nil).count
  end

  def assign_default_role
    @just_created = true
    add_role(:submitter, default_group) unless has_role?(:submitter, default_group)
    enable_messages_from(group: default_group)
  end

  # Returns true if the user has notification e-mails enabled
  # @return [Boolean]
  def email_messages_enabled?
    email_messages_enabled
  end

  # Permit this user to receive notification messages for members of a given Group
  # @param group [Group]
  def enable_messages_from(group:)
    raise(ArgumentError, "User #{uid} is not an administrator or depositor for the group #{group.title}") unless can_admin?(group) || can_submit?(group)
    group_messaging_options << GroupOption.new(option_type: GroupOption::EMAIL_MESSAGES, user: self, group: group)
  end

  # Disable this user from receiving notification messages for members of a given Group
  # @param group [Group]
  def disable_messages_from(group:)
    raise(ArgumentError, "User #{uid} is not an administrator or depositor for the group #{group.title}") unless can_admin?(group) || can_submit?(group)
    groups_with_messaging.destroy(group)
  end

  # Returns true if the user has notification e-mails enabled for a given group
  # @param group [Group]
  # @return [Boolean]
  def messages_enabled_from?(group:)
    found = group_messaging_options.find_by(group: group)

    !found.nil?
  end
end
# rubocop:enable Metrics/ClassLength
