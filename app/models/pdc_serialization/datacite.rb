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
  #   jsonb_hash = JSON.parse({...}.to_json)
  #   resource = PDCMetadata::Resource.new_from_jsonb(jsonb_hash)
  #   datacite_xml = PDCSerialization::Datacite.new_from_work_resource(resource).to_xml
  #
  # For information
  #   Datacite schema: https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  #   Datacite mapping gem: https://github.com/CDLUC3/datacite-mapping
  #
  # rubocop:disable Metrics/ClassLength
  class Datacite
    attr_reader :mapping, :errors

    def initialize(mapping)
      @mapping = mapping
      @errors = []
    end

    # Returns the XML serialization for the Datacite record
    # Note that the actual XML serialization is done by the datacite-mapping gem.
    def to_xml
      @mapping.write_xml
    end

    # Validate this DataCite XML serialization against the official DataCite schema
    # By default we validate against DataCite 4.4. This will shift over time as new
    # versions of the datacite schema are released.
    # @return [Boolean]
    def valid?
      @errors = []
      datacite_xml = Nokogiri::XML(to_xml)
      schema_location = Rails.root.join("config", "schema")
      Dir.chdir(schema_location) do
        xsd = Nokogiri::XML::Schema(File.read("datacite_4_4.xsd"))
        xsd.validate(datacite_xml).each do |error|
          @errors << error
        end
      end
      return true if @errors.empty?
      false
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
        contributors: contributors_from_work_resource(resource.contributors),
        descriptions: descriptions_from_work_resource(resource.description),
        titles: titles_from_work_resource(resource.titles),
        publisher: ::Datacite::Mapping::Publisher.new(value: resource.publisher),
        publication_year: resource.publication_year,
        resource_type: datacite_resource_type(resource.resource_type),
        related_identifiers: related_identifiers_from_work_resource(resource),
        rights_list: rights_from_work_resource(resource),
        version: resource.version_number,
        funding_references: funding_references_from_work_resource(resource)
      )
      Datacite.new(mapping)
    end

    class << self
      def datacite_resource_type(value)
        resource_type = ::Datacite::Mapping::ResourceTypeGeneral.find_by_value(value)
        ::Datacite::Mapping::ResourceType.new(resource_type_general: resource_type)
      end

      def datacite_contributor_type(value)
        ::Datacite::Mapping::ContributorType.find_by_value(value)
      end

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

        def contributors_from_work_resource(contributors)
          contributors.sort_by(&:sequence).map do |contributor|
            ::Datacite::Mapping::Contributor.new(
              name: contributor.value,
              identifier: name_identifier_from_identifier(contributor.identifier),
              affiliations: nil,
              type: datacite_contributor_type(contributor.type)
            )
          end
        end

        ##
        # We are deliberately not differentiating between "abstract", "methods" and other kinds of descriptions.
        # We are instead putting all description into the same field and classifying it as "OTHER".
        def descriptions_from_work_resource(description)
          return [] if description.blank?
          [] << ::Datacite::Mapping::Description.new(type: ::Datacite::Mapping::DescriptionType::OTHER, value: description)
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
            else
              title_type = ::Datacite::Mapping::TitleType.find_by_value(title.title_type)
              ::Datacite::Mapping::Title.new(value: title.title, type: title_type) if title_type
            end
          end.compact
        end

        ##
        # Add related identifiers from various locations in the metadata.
        # @param [PDCMetadata::Resource] resource
        # @return [<::Datacite::Mapping::RelatedIdentifier>]
        def related_identifiers_from_work_resource(resource)
          related_identifiers = []
          related_identifiers = related_identifiers.union(extract_ark_as_related_identfier(resource))
          related_identifiers = related_identifiers.union(extract_related_objects(resource))
          related_identifiers
        end

        def extract_ark_as_related_identfier(resource)
          related_ids = []
          if resource.ark.present?
            related_ids << ::Datacite::Mapping::RelatedIdentifier.new(
              relation_type: ::Datacite::Mapping::RelationType::IS_IDENTICAL_TO,
              value: resource.ark,
              identifier_type: ::Datacite::Mapping::RelatedIdentifierType::ARK
            )
          end
          related_ids
        end

        def extract_related_objects(resource)
          related_objects = []
          resource.related_objects.each do |ro|
            related_objects << ::Datacite::Mapping::RelatedIdentifier.new(
              relation_type: ::Datacite::Mapping::RelationType.find_by_value(ro.relation_type),
              value: ro.related_identifier,
              identifier_type: ::Datacite::Mapping::RelatedIdentifierType.find_by_value(ro.related_identifier_type)
            )
          end
          related_objects
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

        def funding_references_from_work_resource(resource)
          resource.funders.map do |funder|
            award = ::Datacite::Mapping::AwardNumber.new(uri: funder.award_uri, value: funder.award_number)
            if funder.ror.present?
              funder_identifier = ::Datacite::Mapping::FunderIdentifier.new(type: "ROR", value: funder.ror)
              ::Datacite::Mapping::FundingReference.new(name: funder.funder_name, award_number: award, funder_identifier: funder_identifier)
            else
              ::Datacite::Mapping::FundingReference.new(name: funder.funder_name, award_number: award)
            end
          end
        end
      end
  end
  # rubocop:enable Metrics/ClassLength
end
