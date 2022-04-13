# frozen_string_literal: true

class Dataset < ApplicationRecord
  belongs_to :collection

  def self.create_skeleton(title, user_id, collection_id)
    ds = Dataset.new(
      title: title,
      profile: "DublinCore",
      ark: Ark.mint,
      created_by_user_id: user_id,
      collection_id: collection_id
    )
    ds.save
    ds
  end

  def ark_url
    "https://ezid.cdlib.org/id/#{ark}"
  end

  def created_by_user
    User.find(created_by_user_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
