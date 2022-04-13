# frozen_string_literal: true

class Dataset < ApplicationRecord
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
end
