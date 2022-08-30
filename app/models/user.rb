# frozen_string_literal: true
require "csv"

# rubocop:disable Metrics/ClassLength
class User < ApplicationRecord
  rolify
  extend FriendlyId
  friendly_id :uid

  devise :rememberable, :omniauthable
  after_create :assign_default_role

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
    user.display_name = access_token.extra.givenname || access_token.uid # Harriet
    user.family_name = access_token.extra.sn || access_token.uid # Tubman
    user.full_name = access_token.extra.displayname || access_token.uid # "Harriet Tubman"
    user.default_collection_id = Collection.default_for_department(access_token.extra.departmentnumber)&.id
    user.save!
    user
  end

  # Updates an existing User record with some information from CAS. This is useful
  # for records created before the user ever logged in (e.g. to gran them permissions
  # to collections).
  def update_with_cas(access_token)
    self.provider = access_token.provider
    self.email = access_token.extra.mail
    self.display_name = access_token.extra.givenname || access_token.uid # Harriet
    self.family_name = access_token.extra.sn || access_token.uid # Tubman
    self.full_name = access_token.extra.displayname || access_token.uid # "Harriet Tubman"
    self.default_collection_id = Collection.default_for_department(access_token.extra.departmentnumber)&.id
    save!
  end

  # Creates a new user by uid. If the user already exists it returns the existing user.
  def self.new_for_uid(uid, roles: [])
    user = User.find_by(uid: uid)
    if user.nil?
      user = User.new(uid: uid, email: "#{uid}@princeton.edu")
      user.save!
    end
    roles.each do |role|
      user.add_role(role) unless user.has_role?(role)
    end
    user
  end

  # rubocop:disable Metrics/MethodLength
  def self.new_from_csv_params(csv_params)
    email = "#{csv_params['Net ID']}@princeton.edu"
    uid = csv_params["Net ID"]
    full_name = "#{csv_params['First Name']} #{csv_params['Last Name']}"
    display_name = csv_params["First Name"]
    orcid = csv_params["ORCID ID"]
    user = User.where(email: email).first_or_create
    params_hash = {
      email: email,
      uid: uid,
      orcid: orcid,
      full_name: (full_name if user.full_name.blank?),
      display_name: (display_name if user.display_name.blank?)
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
  # and the default administrators and submitters for each collection.
  # It only creates missing records, i.e. if the records already exist it
  # will not create a duplicate. It also does _not_ remove already configured
  # access to other collections.
  def self.create_default_users
    update_super_admins

    Collection.find_each do |collection|
      Rails.logger.info "Setting up admins for collection #{collection.title}"
      collection.default_admins_list.each do |uid|
        user = User.new_for_uid(uid)
        user.add_role :collection_admin, collection
      end

      Rails.logger.info "Setting up submitters for collection #{collection.title}"
      collection.default_submitters_list.each do |uid|
        user = User.new_for_uid(uid)
        user.add_role :submitter, collection
      end
    end
  end

  def self.update_super_admins
    Rails.logger.info "Setting super administrators"
    Rails.configuration.super_admins.each { |uid| User.new_for_uid(uid, roles: [:super_admin]) }
  end

  # Returns a string with the UID (netid) for all the users.
  # We use this string to power the JavaScript @mention functionality when adding comments to works.
  def self.all_uids_string
    User.all.map { |user| '"' + user.uid + '"' }.join(", ")
  end

  ##
  # Is this user a super_admin? super_admins automatically get admin status in every
  # collection, and they can make new collections.
  # @return [Boolean]
  def super_admin?
    has_role? :super_admin
  rescue
    false
  end

  # Returns a display name that always has a value
  # This is needed because we have records in the Users table that are created automatically
  # in which the only value we have for sure its their uid (aka NetID).
  def display_name_safe
    display_name.presence || uid
  end

  def curator?
    admin_collections.count > 0
  end

  # Returns a reference to the user's default collection.
  def default_collection
    if default_collection_id.nil?
      Collection.default
    else
      Collection.find(default_collection_id)
    end
  end

  # True if the user can submit datasets to the collection
  def can_submit?(collection)
    return true if super_admin?
    has_role?(:submitter, collection)
  end

  # Returns true if the user can admin the collection
  def can_admin?(collection)
    return true if super_admin?
    has_role? :collection_admin, collection
  end

  # Returns the list of collections where the user can submit datasets
  def submitter_collections
    @submitter_collections = if super_admin?
                               Collection.all.to_a
                             else
                               Collection.with_role(:submitter, self)
                             end
  end

  # Returns the list of collections where the user is an administrator
  def admin_collections
    @admin_collections ||= if super_admin?
                             Collection.all.to_a
                           else
                             Collection.with_role(:collection_admin, self)
                           end
  end

  def pending_notifications_count
    WorkActivityNotification.where(user_id: id, read_at: nil).count
  end

  def assign_default_role
    add_role(:submitter, default_collection) if roles.blank?
  end
end
# rubocop:enable Metrics/ClassLength
