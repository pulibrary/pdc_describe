# frozen_string_literal: true
# Class for storing a related object
module PDCMetadata
  # let(:related_identifier) { "https://www.biorxiv.org/content/10.1101/545517v1" }
  # let(:related_identifier_type) { "arXiv" }
  # let(:relation_type) { "IsCitedBy" }
  class RelatedObject
    attr_accessor :related_identifier, :related_identifier_type, :relation_type, :errors

    def initialize(related_identifier:, related_identifier_type:, relation_type:)
      @related_identifier = related_identifier
      @related_identifier_type = related_identifier_type
      @relation_type = relation_type
      @errors = []
    end

    def valid?
      valid = related_identifier.present? && valid_related_identifier_type? && valid_relation_type?
      return valid if valid
      if related_identifier.blank?
        errors << "Related identifier is missing"
      else
        errors << "Related Identifier Type is missing or invalid for #{related_identifier}" unless valid_related_identifier_type?
        errors << "Relationship Type is missing or invalid for #{related_identifier}" unless valid_relation_type?
      end
      false
    end

    def value
      @related_identifier
    end

    def compare_value
      "#{related_identifier} ('#{relation_type}' relation #{related_identifier_type})"
    end

    def self.new_related_object(related_identifier, related_identifier_type, relation_type)
      RelatedObject.new(related_identifier: related_identifier, related_identifier_type: related_identifier_type, relation_type: relation_type)
    end

    private

      def valid_related_identifier_type?
        @valid_related_identifier_type ||= valid_type_values.include?(related_identifier_type)
      end

      def valid_relation_type?
        @valid_relation_type ||= valid_relationship_types.include?(relation_type)
      end

      def valid_type_values
        @valid_type_values ||= Datacite::Mapping::RelatedIdentifierType.map(&:value)
      end

      def valid_relationship_types
        @valid_relationship_types ||= Datacite::Mapping::RelationType.map(&:value)
      end
  end
end
