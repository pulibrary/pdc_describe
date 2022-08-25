# frozen_string_literal: true
# Class for storing a creator in our local representation
module PDCMetadata
  # value: "Miller, Elizabeth"
  # name_type: "Personal"
  # given_name: "Elizabeth"
  # family_name: "Miller"
  class Creator
    attr_accessor :value, :name_type, :given_name, :family_name, :identifier, :affiliations, :sequence

    class << self
      def from_hash(creator)
        given_name = creator["given_name"]
        family_name = creator["family_name"]
        orcid = creator.dig("identifier", "scheme") == "ORCID" ? creator.dig("identifier", "value") : nil
        sequence = (creator["sequence"] || "").to_i
        PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
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

    def self.new_person(given_name, family_name, orcid_id = nil, sequence = 0)
      full_name = "#{family_name}, #{given_name}"
      creator = Creator.new(value: full_name, name_type: "Personal", given_name: given_name, family_name: family_name, sequence: sequence)
      if orcid_id.present?
        creator.identifier = NameIdentifier.new_orcid(orcid_id.strip)
      end
      creator
    end

    def to_xml(builder)
      if name_type == "Personal"
        builder.creator("nameType" => "Personal") do
          builder.creatorName value
          builder.givenName given_name
          builder.familyName family_name
          identifier&.to_xml(builder)
        end
      else
        builder.creator("nameType" => "Organization") do
          builder.creatorName value
        end
      end
    end
  end
end
