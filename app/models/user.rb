# frozen_string_literal: true

class User < ApplicationRecord
  extend FriendlyId
  friendly_id :uid

  devise :rememberable, :omniauthable

  validate do |user|
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
    user.setup_user_default_collections
    user
  end

  # Create a new user with some basic information from CAS.
  def self.new_from_cas(access_token)
    user = User.new
    user.provider = access_token.provider
    user.uid = access_token.uid # this is the netid
    user.email = access_token.extra.mail
    user.display_name = access_token.extra.givenname || access_token.uid # Harriet
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
    self.full_name = access_token.extra.displayname || access_token.uid # "Harriet Tubman"
    self.default_collection_id = Collection.default_for_department(access_token.extra.departmentnumber)&.id
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

  # Creates the default users as indicated in the superadmin config file
  # and the default administrators and submitters for each collection.
  # It only creates missing records, i.e. if the records already exist it
  # will not create a duplicate. It also does _not_ remove already configured
  # access to other collections.
  def self.create_default_users
    Rails.logger.info "Setting super administrators"
    Rails.configuration.superadmins.each { |uid| User.new_for_uid(uid) }

    Collection.find_each do |collection|
      Rails.logger.info "Setting up admins for collection #{collection.title}"
      collection.default_admins_list.each do |uid|
        user = User.new_for_uid(uid)
        UserCollection.add_admin(user.id, collection.id)
      end

      Rails.logger.info "Setting up submitters for collection #{collection.title}"
      collection.default_submitters_list.each do |uid|
        user = User.new_for_uid(uid)
        UserCollection.add_submitter(user.id, collection.id)
      end
    end
  end

  ##
  # Is this user a superadmin? Superadmins automatically get admin status in every
  # collection, and they can make new collections.
  # @return [Boolean]
  def superadmin?
    Rails.configuration.superadmins.include? uid
  rescue
    false
  end

  # Returns a reference to the user's default collection.
  def default_collection
    if default_collection_id.nil?
      Collection.default
    else
      Collection.find(default_collection_id)
    end
  end

  # Adds the user to the collections that they should have access by default
  def setup_user_default_collections
    # Makes sure the user has submit access to their default collection
    if UserCollection.can_submit?(id, default_collection_id) == false
      UserCollection.add_submitter(id, default_collection_id)
    end
  end

  # True if the user can submit datasets to the collection
  def can_submit?(collection_id)
    return true if superadmin?
    UserCollection.can_submit?(id, collection_id)
  end

  # Returns true if the user can admin the collection
  def can_admin?(collection_id)
    return true if superadmin?
    UserCollection.can_admin?(id, collection_id)
  end

  # Returns the list of collections where the user can submit datasets
  def submitter_collections
    return Collection.all.to_a if superadmin?
    UserCollection.where(user_id: id).filter(&:can_submit?).map(&:collection)
  end
end
