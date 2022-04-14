# frozen_string_literal: true

class User < ApplicationRecord
  devise :rememberable, :omniauthable

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
      user.default_collection_id = Collection.default_for_department(access_token.extra.departmentnumber)&.id
      user.save!
    end
    user
  end

  def default_collection
    if default_collection_id.nil?
      Collection.default
    else
      Collection.find(default_collection_id)
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
end
