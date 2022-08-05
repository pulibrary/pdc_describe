# frozen_string_literal: true
module PULDatacite
  # Represents a PUL Datacite resource.
  # This class should be instantiated via the `.new_from_json` method.
  # It takes PDC Describe form submission data and turns it into valid Datacite.
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  # Note that the actual datacite mapping and XML serialization is done by the datacite-mapping gem.
  class Resource
    attr_accessor :metadata_from_form, :identifier, :identifier_type, :creators, :titles, :publisher, :publication_year, :resource_type, :description

    # Creates a PULDatacite::Resource from a JSON string
    # @param [JSON] json_string - The JSON emitted by a form submission
    def self.new_from_json(json_string)
      resource = PULDatacite::Resource.new
      resource.metadata_from_form = json_string.blank? ? {} : JSON.parse(json_string)
      resource.datacite_mapping
      resource
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
        titles: datacite_titles,
        publisher: datacite_publisher,
        publication_year: @metadata_from_form["publication_year"],
        # subjects: [],
        # contributors: [],
        # dates: [],
        # language: nil,
        # funding_references: [],
        resource_type: datacite_resource_type(@metadata_from_form["resource_type"])
        # alternate_identifiers: [],
        # related_identifiers: [],
        # sizes: [],
        # formats: [],
        # version: nil,
        # rights_list: [],
        # descriptions: [],
        # geo_locations: []
      )
    end

    def to_xml
      datacite_mapping.write_xml
    end

    ##
    # For each creator, make a Datacite::Mapping::Creator object
    # TODO: This class has no field for author order. We need a place to record that.
    def datacite_creators
      creator_array = []
      @metadata_from_form["creators"].each do |creator|
        creator_array << Datacite::Mapping::Creator.new(
          name: creator["value"],
          given_name: creator["given_name"],
          family_name: creator["family_name"],
          affiliations: creator["affiliations"]
        )
      end
      creator_array
    end

    ##
    # For each title, make a Datacite::Mapping::Title object
    # TODO: Add qualifiers for different kinds of titles
    def datacite_titles
      title_array = []
      @metadata_from_form["titles"].each do |title|
        title_array << Datacite::Mapping::Title.new(value: title["title"])
      end
      title_array
    end

    ##
    # Given a resource type string, assign the appropriate Datacite::Resource::ResourceType
    # @param [String] resource_type
    def datacite_resource_type(resource_type)
      resource_type_general = case resource_type.downcase
                              when "dataset"
                                Datacite::Mapping::ResourceTypeGeneral::DATASET
                              else
                                Datacite::Mapping::ResourceTypeGeneral::OTHER
                              end
      Datacite::Mapping::ResourceType.new(resource_type_general: resource_type_general)
    end

    ##
    # Given a DOI, format it as a Datacite::Mapping::Identifier
    def datacite_identifier
      Datacite::Mapping::Identifier.new(value: @metadata_from_form["identifier"])
    end

    def datacite_publisher
      Datacite::Mapping::Publisher.new(value: @metadata_from_form["publisher"])
    end
  end
end
