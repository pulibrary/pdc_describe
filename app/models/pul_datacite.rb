# frozen_string_literal: true
module PULDatacite
  # Represents a PUL Datacite resource
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  class Resource
    attr_accessor :identifier, :identifier_type, :creators, :titles, :publisher, :publication_year, :resource_type, :description

    def initialize(identifier: nil, identifier_type: nil, title: nil, resource_type: nil)
      @identifier = identifier
      @identifier_type = identifier_type
      @titles = []
      @titles << PULDatacite::Title.new(title: title) unless title.nil?
      @description = nil
      @creators = []
      @resource_type = resource_type || "Dataset"
      @publisher = "Princeton University"
      @publication_year = Time.zone.today.year
    end

    def main_title
      @titles.find(&:main?)&.title
    end

    def other_titles
      @titles.select { |title| title.main? == false }
    end

    ##
    # For each creator, make a Datacite::Mapping::Creator object
    def datacite_creators
      creator_array = []
      @creators.each do |creator|
        creator_array << Datacite::Mapping::Creator.new(name: creator.value)
      end
      creator_array
    end

    ##
    # Given a DOI, format it as a Datacite::Mapping::Identifier
    def datacite_identifier
      Datacite::Mapping::Identifier.new(value: @identifier)
    end

    ##
    # Create a new Datacite::Mapping::Resource object
    def datacite_mapping
      # @param identifier [Identifier] a persistent identifier that identifies a resource.
      # @param creators [Array<Creator>] the main researchers involved working on the data, or the authors of the publication in priority order.
      # @param titles [Array<Title>] the names or titles by which a resource is known.
      # @param publisher [Publisher] the name of the entity that holds, archives, publishes prints, distributes, releases, issues, or produces the resource.
      # @param publication_year [Integer] year when the resource is made publicly available.
      # @param subjects [Array<Subject>] subjects, keywords, classification codes, or key phrases describing the resource.
      # @param funding_references [Array<FundingReference>] information about financial support (funding) for the resource being registered.
      # @param contributors [Array<Contributor>] institutions or persons responsible for collecting, creating, or otherwise contributing to the developement of the dataset.
      # @param dates [Array<Date>] different dates relevant to the work.
      # @param language [String, nil] Primary language of the resource: an IETF BCP 47, ISO 639-1 language code.
      # @param resource_type [ResourceType, nil] the type of the resource
      # @param alternate_identifiers [Array<AlternateIdentifier>] an identifier or identifiers other than the primary {Identifier} applied to the resource being registered.
      # @param related_identifiers [Array<RelatedIdentifier>] identifiers of related resources.
      # @param sizes [Array<String>] unstructured size information about the resource.
      # @param formats [Array<String>] technical format of the resource, e.g. file extension or MIME type.
      # @param version [String] version number of the resource.
      # @param rights_list [Array<Rights>] rights information for this resource.
      # @param descriptions [Array<Description>] all additional information that does not fit in any of the other categories.
      # @param geo_locations [Array<GeoLocations>] spatial region or named place where the data was gathered or about which the data is focused.
      Datacite::Mapping::Resource.new(
        identifier: datacite_identifier,
        creators: datacite_creators,
        titles: [main_title],
        publisher: "Fake Publisher",
        publication_year: 1999,
        subjects: [],
        contributors: [],
        dates: [],
        language: nil,
        funding_references: [],
        resource_type: nil,
        alternate_identifiers: [],
        related_identifiers: [],
        sizes: [],
        formats: [],
        version: nil,
        rights_list: [],
        descriptions: [],
        geo_locations: []
      )
    end

    def to_xml
      datacite_mapping.write_xml
    end

    # Creates a PULDatacite::Resource from a JSON string
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def self.new_from_json(json_string)
      resource = PULDatacite::Resource.new
      hash = json_string.blank? ? {} : JSON.parse(json_string)

      resource.description = hash["description"]

      hash["titles"]&.each do |title|
        resource.titles << PULDatacite::Title.new(title: title["title"], title_type: title["title_type"])
      end

      hash["creators"]&.each do |creator|
        given_name = creator["given_name"]
        family_name = creator["family_name"]
        orcid = creator.dig("name_identifier", "scheme") == "ORCID" ? creator.dig("name_identifier", "value") : nil
        sequence = (creator["sequence"] || "").to_i
        resource.creators << PULDatacite::Creator.new_person(given_name, family_name, orcid, sequence)
      end
      resource.creators.sort_by!(&:sequence)

      resource.publisher = hash["publisher"]
      resource.publication_year = hash["publication_year"]

      resource
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
  end

  # value: "Miller, Elizabeth"
  # name_type: "Personal"
  # given_name: "Elizabeth"
  # family_name: "Miller"
  class Creator
    attr_accessor :value, :name_type, :given_name, :family_name, :name_identifier, :affiliations, :sequence

    # rubocop:disable Metrics/ParameterLists
    def initialize(value: nil, name_type: nil, given_name: nil, family_name: nil, name_identifier: nil, sequence: 0)
      @value = value
      @name_type = name_type
      @given_name = given_name
      @family_name = family_name
      @name_identifier = name_identifier
      @affiliations = []
      @sequence = sequence
    end
    # rubocop:enable Metrics/ParameterLists

    def orcid_url
      name_identifier&.orcid_url
    end

    def orcid
      name_identifier&.orcid
    end

    def self.new_person(given_name, family_name, orcid_id = nil, sequence = 0)
      full_name = "#{family_name}, #{given_name}"
      creator = Creator.new(value: full_name, name_type: "Personal", given_name: given_name, family_name: family_name, sequence: sequence)
      if orcid_id.present?
        creator.name_identifier = NameIdentifier.new_orcid(orcid_id.strip)
      end
      creator
    end
  end

  # value:      "0000-0001-5000-0007"
  # scheme:     "ORCID"
  # scheme_uri: "https://orcid.org/""
  class NameIdentifier
    attr_accessor :value, :scheme, :scheme_uri
    def initialize(value: nil, scheme: nil, scheme_uri: nil)
      @value = value
      @scheme = scheme
      @scheme_uri = scheme_uri
    end

    def orcid_url
      return nil unless scheme == "ORCID"
      "#{scheme_uri}/#{value}"
    end

    def orcid
      return nil unless scheme == "ORCID"
      value
    end

    # Convenience method since this is the most common (only?) identifier that we are currently supporting
    def self.new_orcid(value)
      NameIdentifier.new(value: value, scheme: "ORCID", scheme_uri: "https://orcid.org")
    end
  end

  # value:      "datacite"
  # identifier: "https://ror.org/04aj4c181"
  # scheme:     "ROR"
  # scheme_uri: "https://ror.org/"
  class Affiliation
    attr_accessor :value, :identifier, :scheme, :scheme_uri
    def initialize(value: nil, identifier: nil, scheme: nil, scheme_uri: nil)
      @value = value
      @identifier = identifier
      @scheme = scheme
      @scheme_uri = scheme_uri
    end
  end

  # value:      "100 años de soledad"
  # title_type: "TranslatedTitle"
  class Title
    attr_accessor :title, :title_type
    def initialize(title:, title_type: nil)
      @title = title
      @title_type = title_type
    end

    def main?
      @title_type.blank?
    end
  end
end
