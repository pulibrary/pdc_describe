# frozen_string_literal: true
# Class for storing a creator in our local representation
module PDCMetadata
  # value: "Miller, Elizabeth"
  # name_type: "Personal"
  # given_name: "Elizabeth"
  # family_name: "Miller"
  class Creator
    attr_accessor :value, :name_type, :given_name, :family_name, :identifier, :affiliations, :sequence, :type

    class << self
      def from_hash(creator)
        given_name = creator["given_name"]
        family_name = creator["family_name"]
        orcid = creator.dig("identifier", "scheme") == "ORCID" ? creator.dig("identifier", "value") : nil
        sequence = (creator["sequence"] || "").to_i
        PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
      end

      def individual_contributor_from_hash(contributor)
        given_name = contributor["given_name"]
        family_name = contributor["family_name"]
        orcid = contributor.dig("identifier", "scheme") == "ORCID" ? contributor.dig("identifier", "value") : nil
        sequence = (contributor["sequence"] || "").to_i
        type = contributor["type"]
        PDCMetadata::Creator.new_individual_contributor(given_name, family_name, orcid, type, sequence)
      end

      def organizational_contributor_from_hash(contributor)
        name = contributor["name"]
        ror = contributor.dig("identifier", "scheme") == "ROR" ? contributor.dig("identifier", "value") : nil
        type = contributor["type"]
        PDCMetadata::Creator.new_organizational_contributor(name, ror, type)
      end
    end

    # rubocop:disable Metrics/ParameterLists
    def initialize(value: nil, name_type: nil, given_name: nil, family_name: nil, identifier: nil, sequence: 0)
      @value = value
      @name_type = name_type
      @given_name = given_name
      @family_name = family_name
      @identifier = identifier
      @affiliations = []
      @sequence = sequence
    end
    # rubocop:enable Metrics/ParameterLists

    def orcid_url
      identifier&.orcid_url
    end

    def orcid
      identifier&.orcid
    end

    def ror_url
      identifier&.ror_url
    end

    def ror
      identifier&.ror
    end

    def compare_value
      "#{value} | #{sequence} | #{type}"
    end

    def self.new_person(given_name, family_name, orcid_id = nil, sequence = 0)
      full_name = "#{family_name}, #{given_name}"
      creator = Creator.new(value: full_name, name_type: "Personal", given_name: given_name, family_name: family_name, sequence: sequence)
      if orcid_id.present?
        creator.identifier = NameIdentifier.new_orcid(orcid_id.strip)
      end
      creator
    end

    def self.new_individual_contributor(given_name, family_name, orcid_id, type, sequence)
      # TODO: If type is always "Personal", it shouldn't be required as a parameter.
      contributor = new_person(given_name, family_name, orcid_id, sequence)
      contributor.type = type
      contributor
    end

    def self.new_organization(name, ror = nil)
      creator = Creator.new(value: name, name_type: "Organizational")
      if ror.present?
        creator.identifier = NameIdentifier.new_ror(ror.strip)
      end
      creator
    end

    def self.new_organizational_contributor(name, ror, type)
      # TODO: If type is always "Organizational", it shouldn't be required as a parameter.
      contributor = new_organization(name, ror)
      contributor.type = type
      contributor
    end
  end
end
