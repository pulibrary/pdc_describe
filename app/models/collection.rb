# frozen_string_literal: true

# rubocop:disable Style/NumericPredicate
class Collection < ApplicationRecord
  def self.create_defaults
    return if Collection.count > 0
    Rails.logger.info "Creating default Collections"
    Collection.create(title: "Research Data", code: "RD")
    Collection.create(title: "Princeton Plasma Physics Laboratory ", code: "PPPL")
    Collection.create(title: "Electronic Theses and Dissertations", code: "ETD")
    Collection.create(title: "Library Resources", code: "LIB")
  end
end
# rubocop:enable Style/NumericPredicate
