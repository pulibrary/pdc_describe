# frozen_string_literal: true

# rubocop:disable Style/NumericPredicate
class Collection < ApplicationRecord
  def self.create_defaults
    return if Collection.count > 0
    # TODO: Define proper default collections, perhaps from DataSpace?
    Rails.logger.info "Creating default Collections"
    Collection.create(title: "Sample Collection 1")
    Collection.create(title: "Sample Collection 2")
  end
end
# rubocop:enable Style/NumericPredicate
