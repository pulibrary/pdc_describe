# frozen_string_literal: true
# Class for storing a related object
module PDCMetadata
  # let(:related_identifier) { "https://www.biorxiv.org/content/10.1101/545517v1" }
  # let(:related_identifier_type) { "arXiv" }
  # let(:relation_type) { "IsCitedBy" }
  class RelatedObject
    attr_accessor :related_identifier, :related_identifier_type, :relation_type

    def initialize(related_identifier:, related_identifier_type:, relation_type:)
      @related_identifier = related_identifier
      @related_identifier_type = related_identifier_type
      @relation_type = relation_type
    end

    def value
      @related_identifier
    end

    def self.new_related_object(related_identifier, related_identifier_type, relation_type)
      RelatedObject.new(related_identifier: related_identifier, related_identifier_type: related_identifier_type, relation_type: relation_type)
    end

    ##
    # Generate a list of valid options for the related_identifier_type field
    def self.related_identifier_type_options
      pairs = Datacite::Mapping::RelatedIdentifierType.to_a.map { |value| [value.key, value.value] }
      built = Hash[pairs]
      built.with_indifferent_access
    end

    ##
    # Generate a list of valid options for the relation_type field
    def self.relation_type_options
      pairs = Datacite::Mapping::RelationType.to_a.map { |value| [value.key, value.value] }
      built = Hash[pairs]
      built.with_indifferent_access
    end
  end
end
