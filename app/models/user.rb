# frozen_string_literal: true

class User < ApplicationRecord
  devise :rememberable, :omniauthable

  validate do |user|
    if user.orcid.present? && Orcid.invalid?(user.orcid)
      user.errors.add :base, "Invalid format for ORCID"
    end
  end

  def self.from_cas(access_token)
    user = User.find_by(provider: access_token.provider, uid: access_token.uid)
    if user.nil?
      # Create the user with some basic information from CAS.
      #
      # Other bits of information that we could use are:
      #
      #   access_token.extra.department (e.g. "Library - Information Technology")
      #   access_token.extra.departmentnumber (e.g. "41006")
      #   access_token.extra.givenname (e.g. "Harriet")
      #   access_token.extra.displayname (e.g. "Harriet Tubman")
      #
      user = User.new
      user.provider = access_token.provider
      user.uid = access_token.uid # this is the netid
      user.email = access_token.extra.mail
      user.display_name = access_token.extra.givenname || access_token.uid # Harriet
      user.full_name = access_token.extra.displayname || access_token.uid # "Harriet Tubman"
      user.default_collection_id = Collection.default_for_department(access_token.extra.departmentnumber)&.id
      user.save!
      user.setup_user_default_collections
    end
    user
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
    return if UserCollection.where(user_id: id).count > 0
    # Give users submitter access to their default collection
    UserCollection.add_submitter(id, default_collection_id)
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
