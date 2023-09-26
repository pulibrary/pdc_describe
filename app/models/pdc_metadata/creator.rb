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
        pdc_creator = PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
        pdc_creator.affiliations = (creator["affiliations"])&.map do |affiliation|
          PDCMetadata::Affiliation.new(value: affiliation["value"], identifier: affiliation["identifier"],
                                       scheme: affiliation["scheme"], scheme_uri: affiliation["scheme_uri"])
        end
        pdc_creator
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
        value = contributor["value"]
        ror = contributor.dig("identifier", "scheme") == "ROR" ? contributor.dig("identifier", "value") : nil
        type = contributor["type"]
        PDCMetadata::Creator.new_organizational_contributor(value, ror, type)
      end
    end

    # rubocop:disable Metrics/ParameterLists
    def initialize(value: nil, name_type: nil, given_name: nil, family_name: nil, identifier: nil, sequence: 0, affiliations: [])
      @value = value&.strip
      @name_type = name_type&.strip
      @given_name = given_name&.strip
      @family_name = family_name&.strip
      @identifier = identifier&.strip
      @affiliations = affiliations
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
      "#{value} | #{sequence} | #{type} | #{affiliations.map(&:compare_value).join(',')} | #{orcid_url}"
    end

    def affiliation
      return "" if affiliations.empty?
      affiliations.first.value
    end

    def affiliation_ror
      ror_affiliations = affiliations.select { |affiliation| affiliation.scheme == "ROR" }
      return "" if ror_affiliations.empty?
      ror_affiliations.first.identifier
    end

    def self.new_person(given_name, family_name, orcid_id = nil, sequence = 0, ror: nil, affiliation: nil)
      full_name = "#{family_name&.strip}, #{given_name&.strip}"
      creator = Creator.new(value: full_name, name_type: "Personal", given_name:, family_name:, sequence:)
      if orcid_id.present?
        creator.identifier = NameIdentifier.new_orcid(orcid_id.strip)
      end
      if affiliation.present? || ror.present?
        creator.affiliations << Affiliation.new_affiliation(value: affiliation, ror:)
      end
      creator
    end

    def self.new_individual_contributor(given_name, family_name, orcid_id, type, sequence)
      contributor = new_person(given_name, family_name, orcid_id, sequence)
      contributor.type = type
      contributor
    end

    def self.new_organization(value, ror = nil)
      creator = Creator.new(value:, name_type: "Organizational")
      if ror.present?
        creator.identifier = NameIdentifier.new_ror(ror.strip)
      end
      creator
    end

    def self.new_organizational_contributor(value, ror, type)
      contributor = new_organization(value, ror)
      contributor.type = type
      contributor
    end
  end
end
