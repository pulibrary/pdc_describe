# frozen_string_literal: true

class UserCollection < ApplicationRecord
  belongs_to :collection
  belongs_to :user

  def self.add_submitter(user_id, collection_id)
    uc = UserCollection.where(user_id: user_id, collection_id: collection_id, role: "SUBMITTER")
    if uc.count == 0
      uc = UserCollection.new(user_id: user_id, collection_id: collection_id, role: "SUBMITTER")
      uc.save!
    end
  end

  def self.add_admin(user_id, collection_id)
    uc = UserCollection.where(user_id: user_id, collection_id: collection_id, role: "ADMIN")
    if uc.count == 0
      uc = UserCollection.new(user_id: user_id, collection_id: collection_id, role: "ADMIN")
      uc.save!
    end
  end

  def migrate
    rolify_role = if role == "ADMIN"
                    :collection_admin
                  else
                    :submitter
                  end
    user.add_role rolify_role, collection
  end

  def can_submit?
    role.in?(["SUBMITTER", "ADMIN"])
  end

  def can_admin?
    role == "ADMIN"
  end

  def self.can_submit?(user_id, collection_id)
    user_collection = UserCollection.where(user_id: user_id, collection_id: collection_id).first
    return false if user_collection.nil?
    user_collection.can_submit?
  end
end
