# frozen_string_literal: true
module PDCSerialization
  # The common use for this class is:
  #
  #   work = Work.find(123)
  #   datacite_xml = PDCSerialization::Datacite.new_from_work(work).to_xml
  #
  # For testing purposes you can also quickly get an XML serialization with the helper:
  #
  #   datacite_xml = PDCSerialization::Datacite.skeleton_datacite_xml(...)
  #
  # You can also pass a PDCMetadata::Resource which is useful to test with a more
  # complex dataset without saving the work to the database:
  #
  #   json = {...}.to_json
  #   resource = PDCMetadata::Resource.new_from_json(json)
  #   datacite_xml = PDCSerialization::Datacite.new_from_work_resource(resource).to_xml
  #
  # For information
  #   Datacite schema: https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  #   Datacite mapping gem: https://github.com/CDLUC3/datacite-mapping
  #
  # rubocop:disable Metrics/ClassLength
  class Datacite
    attr_reader :mapping

    def initialize(mapping)
      @mapping = mapping
    end

    # Returns the XML serialization for the Datacite record
    # Note that the actual XML serialization is done by the datacite-mapping gem.
    def to_xml
      @mapping.write_xml
    end

    ##
    # Returns the XML serialization for a valid Datacite skeleton record based on a few required values.
    # Useful for early in the workflow when we don't have much data yet and for testing.
    #
    # @param [String] identifier, e.g "10.1234/567"
    # @param [String] title
    # @param [String] creator
    # @param [String] publisher
    # @param [String] publication_year
    # @param [String] resource_type
    def self.skeleton_datacite_xml(identifier:, title:, creator:, publisher:, publication_year:, resource_type:)
      mapping = ::Datacite::Mapping::Resource.new(
        identifier: ::Datacite::Mapping::Identifier.new(value: identifier),
        creators: [] << ::Datacite::Mapping::Creator.new(name: creator),
        titles: [] << ::Datacite::Mapping::Title.new(value: title),
        publisher: ::Datacite::Mapping::Publisher.new(value: publisher),
        publication_year: publication_year,
        resource_type: datacite_resource_type(resource_type)
      )
      mapping.write_xml
    end

    ##
    # Creates a PDCSerialization::Datacite object from a Work
    def self.new_from_work(work)
      new_from_work_resource(work.resource)
    end

    ##
    # Creates a PDCSerialization::Datacite object from a PDCMetadata::Resource
    def self.new_from_work_resource(resource)
      mapping = ::Datacite::Mapping::Resource.new(
        identifier: ::Datacite::Mapping::Identifier.new(value: resource.doi),
        creators: creators_from_work_resource(resource.creators),
        titles: titles_from_work_resource(resource.titles),
        publisher: ::Datacite::Mapping::Publisher.new(value: resource.publisher),
        publication_year: resource.publication_year,
        resource_type: datacite_resource_type(resource.resource_type),
        related_identifiers: related_identifiers_from_work_resource(resource),
        rights_list: rights_from_work_resource(resource),
        version: resource.version_number
      )
      Datacite.new(mapping)
    end

    class << self
      ##
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/CyclomaticComplexity
      # Returns the appropriate Datacite::Resource::ResourceType for a given string
      # @param [String] resource_type
      def datacite_resource_type(resource_type)
        resource_type_general = case resource_type.downcase
                                when "dataset"
                                  ::Datacite::Mapping::ResourceTypeGeneral::DATASET
                                when "audiovisual"
                                  ::Datacite::Mapping::ResourceTypeGeneral::AUDIOVISUAL
                                when "collection"
                                  ::Datacite::Mapping::ResourceTypeGeneral::COLLECTION
                                when "datapaper"
                                  ::Datacite::Mapping::ResourceTypeGeneral::DATA_PAPER
                                when "event"
                                  ::Datacite::Mapping::ResourceTypeGeneral::EVENT
                                when "image"
                                  ::Datacite::Mapping::ResourceTypeGeneral::IMAGE
                                when "interactiveresource"
                                  ::Datacite::Mapping::ResourceTypeGeneral::INTERACTIVE_RESOURCE
                                when "model"
                                  ::Datacite::Mapping::ResourceTypeGeneral::MODEL
                                when "physicalobject"
                                  ::Datacite::Mapping::ResourceTypeGeneral::PHYSICAL_OBJECT
                                when "service"
                                  ::Datacite::Mapping::ResourceTypeGeneral::SERVICE
                                when "software"
                                  ::Datacite::Mapping::ResourceTypeGeneral::SOFTWARE
                                when "sound"
                                  ::Datacite::Mapping::ResourceTypeGeneral::SOUND
                                when "text"
                                  ::Datacite::Mapping::ResourceTypeGeneral::TEXT
                                when "workflow"
                                  ::Datacite::Mapping::ResourceTypeGeneral::WORKFLOW
                                else
                                  ::Datacite::Mapping::ResourceTypeGeneral::OTHER
                                end
        ::Datacite::Mapping::ResourceType.new(resource_type_general: resource_type_general)
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/CyclomaticComplexity

      private

        def creators_from_work_resource(creators)
          creators.sort_by(&:sequence).map do |creator|
            ::Datacite::Mapping::Creator.new(
              name: creator.value,
              given_name: creator.given_name,
              family_name: creator.family_name,
              identifier: name_identifier_from_identifier(creator.identifier),
              affiliations: nil
            )
          end
        end

        def name_identifier_from_identifier(identifier)
          return nil if identifier.nil?
          ::Datacite::Mapping::NameIdentifier.new(
            scheme: identifier.scheme,
            scheme_uri: identifier.scheme_uri,
            value: identifier.value
          )
        end

        def titles_from_work_resource(titles)
          titles.map do |title|
            if title.main?
              ::Datacite::Mapping::Title.new(value: title.title)
            elsif title.title_type == "Subtitle"
              ::Datacite::Mapping::Title.new(value: title.title, type: ::Datacite::Mapping::TitleType::SUBTITLE)
            elsif title.title_type == "AlternativeTitle"
              ::Datacite::Mapping::Title.new(value: title.title, type: ::Datacite::Mapping::TitleType::ALTERNATIVE_TITLE)
            elsif title.title_type == "TranslatedTitle"
              ::Datacite::Mapping::Title.new(value: title.title, type: ::Datacite::Mapping::TitleType::TRANSLATED_TITLE)
            end
          end.compact
        end

        def related_identifiers_from_work_resource(resource)
          related_identifiers = []
          if resource.ark.present?
            related_identifiers << ::Datacite::Mapping::RelatedIdentifier.new(
              relation_type: ::Datacite::Mapping::RelationType::IS_IDENTICAL_TO,
              value: resource.ark,
              identifier_type: ::Datacite::Mapping::RelatedIdentifierType::ARK
            )
          end
          related_identifiers
        end

        def rights_from_work_resource(resource)
          rights = []
          if resource.rights.present?
            rights << ::Datacite::Mapping::Rights.new(
              value: resource.rights.name,
              uri: resource.rights.uri,
              identifier: resource.rights.identifier
            )
          end
          rights
        end
      end
  end
  # rubocop:enable Metrics/ClassLength
end
