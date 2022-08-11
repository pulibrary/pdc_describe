# frozen_string_literal: true
module ValidDatacite
  # Placeholder while we refactor everything to re-use this class. Then we'll re-name it.
  # Represents a PUL Datacite resource.
  # This class should be instantiated via the `.new_from_json` method.
  # It takes PDC Describe form submission data and turns it into valid Datacite.
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  # Note that the actual datacite mapping and XML serialization is done by the datacite-mapping gem.
  class Resource
    attr_accessor :mapping, :metadata_from_form, :identifier_type, :creators, :titles, :publisher, :publication_year, :resource_type, :description

    ##
    # Create a valid skeleton record. Useful for early in the workflow when we don't have much data yet,
    # and for testing.
    def self.skeleton_datacite_xml(identifier:, title:, creator:, publisher:, publication_year:, resource_type:)
      resource = ValidDatacite::Resource.new
      resource.mapping = Datacite::Mapping::Resource.new(
        identifier: Datacite::Mapping::Identifier.new(value: identifier),
        creators: [] << Datacite::Mapping::Creator.new(name: creator),
        titles: [] << Datacite::Mapping::Title.new(value: title),
        publisher: resource.datacite_publisher(publisher),
        publication_year: publication_year,
        resource_type: resource.datacite_resource_type(resource_type)
      )
      resource.mapping.write_xml
    end

    # Creates a ValidDatacite::Resource from a JSON string
    # @param [JSON] json_string - The JSON emitted by a form submission
    def self.new_from_json(json_string)
      resource = ValidDatacite::Resource.new
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
      @mapping = Datacite::Mapping::Resource.new(
        identifier: datacite_identifier(@metadata_from_form["identifier"]),
        creators: datacite_creators,
        titles: datacite_titles,
        publisher: datacite_publisher(@metadata_from_form["publisher"]),
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
      @mapping
    end

    def to_xml
      datacite_mapping.write_xml
    end

    ##
    # For each creator, make a Datacite::Mapping::Creator object
    # TODO: This class has no field for author order. We need a place to record that.
    def datacite_creators
      @metadata_from_form["creators"].map do |creator|
        Datacite::Mapping::Creator.new(
          name: creator["value"],
          given_name: creator["given_name"],
          family_name: creator["family_name"],
          affiliations: creator["affiliations"]
        )
      end
    end

    ##
    # For each title, make a Datacite::Mapping::Title object
    # TODO: Add qualifiers for different kinds of titles
    def datacite_titles
      @metadata_from_form["titles"].map do |title|
        Datacite::Mapping::Title.new(value: title["title"])
      end
    end

    ##
    # Given a resource type string, assign the appropriate Datacite::Resource::ResourceType
    # @param [String] resource_type
    def datacite_resource_type(resource_type)
      resource_type_general = case resource_type.downcase
                              when "dataset"
                                Datacite::Mapping::ResourceTypeGeneral::DATASET
                              when "audiovisual"
                                Datacite::Mapping::ResourceTypeGeneral::AUDIOVISUAL
                              when "collection"
                                Datacite::Mapping::ResourceTypeGeneral::COLLECTION
                              when "datapaper"
                                Datacite::Mapping::ResourceTypeGeneral::DATA_PAPER
                              when "event"
                                Datacite::Mapping::ResourceTypeGeneral::EVENT
                              else
                                Datacite::Mapping::ResourceTypeGeneral::OTHER
                              end
      Datacite::Mapping::ResourceType.new(resource_type_general: resource_type_general)
    end

    def identifier
      @datacite_identifier.value
    end

    ##
    # Given a DOI, format it as a Datacite::Mapping::Identifier
    def datacite_identifier(identifier)
      @datacite_identifier ||= Datacite::Mapping::Identifier.new(value: identifier)
    end

    def datacite_publisher(publisher)
      Datacite::Mapping::Publisher.new(value: publisher)
    end
  end
end
