# frozen_string_literal: true

# Note that this factory only works with :build, not with :create
FactoryBot.define do
  factory :related_object, class: "PDCMetadata::RelatedObject" do
    transient do
      related_identifier { "10.34770/#{format('%03d', rand(999))}-abc" }
    end
    related_identifier_type { "arXiv" }
    relation_type { "IsCitedBy" }

    initialize_with { new(related_identifier:related_identifier, related_identifier_type: related_identifier_type, relation_type: relation_type) }
  end
end