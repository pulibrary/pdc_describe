# frozen_string_literal: true

class Collection < ApplicationRecord
  def self.create_defaults
    return if Collection.count > 0
    # TODO: Define proper default collections, perhaps from DataSpace?
    Collection.create(title: "Collection 1")
    Collection.create(title: "Collection 2")
  end
end
