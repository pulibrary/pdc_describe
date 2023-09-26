# frozen_string_literal: true

# Note that this factory only works with :build, not with :create
FactoryBot.define do
  factory :related_object, class: "PDCMetadata::RelatedObject" do
    transient do
      related_identifier { "10.34770/#{format('%03d', rand(999))}-abc" }
    end
    related_identifier_type { "DOI" }
    relation_type { "IsCitedBy" }

    factory :related_object_arxiv do
      transient do
        related_identifier { "arXiv:#{rand(20..23)}#{rand(1..12)}.#{format('%03d', rand(999))}v1" }
      end
      related_identifier_type { "arXiv" }
    end

    # Example of a related object that shouldn't link anywhere
    factory :related_object_isbn do
      transient do
        related_identifier { "#{rand(999)}-#{rand(999)}-#{rand(999)}-123X" }
      end
      related_identifier_type { "ISBN" }
    end

    initialize_with { new(related_identifier:, related_identifier_type:, relation_type:) }
  end
end
