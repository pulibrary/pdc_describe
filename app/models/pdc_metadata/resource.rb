# frozen_string_literal: true
module PDCMetadata
  # Represents a PUL Datacite resource
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview

  def self.fuzzy_match(obj, value)
    obj.key.to_s == value or obj.value.casecmp(value).zero?
  end

  class Resource
    attr_accessor :creators, :titles, :publisher, :publication_year, :resource_type, :resource_type_general,
      :description, :doi, :ark, :rights, :version_number, :collection_tags, :keywords, :contributors, :related_objects,
      :funders

    # rubocop:disable Metrics/MethodLength
    def initialize(doi: nil, title: nil, resource_type: nil, resource_type_general: nil, creators: [], description: nil)
      @titles = []
      @titles << PDCMetadata::Title.new(title: title) unless title.nil?
      @description = description
      @collection_tags = []
      @creators = creators
      @resource_type = resource_type || "Dataset"
      @resource_type_general = resource_type_general || self.class.default_resource_type_general
      @publisher = "Princeton University"
      @publication_year = Time.zone.today.year
      @ark = nil
      @doi = doi
      @rights = nil
      @version_number = "1"
      @related_objects = []
      @keywords = []
      @individual_contributors = []
      @organizational_contributors = []
      @funders = []
    end
    # rubocop:enable Metrics/MethodLength

    def identifier
      @doi
    end

    def identifier_type
      return nil if @doi.nil?
      "DOI"
    end

    def main_title
      @titles.find(&:main?)&.title
    end

    def other_titles
      @titles.select { |title| title.main? == false }
    end

    def to_xml
      xml_declaration = '<?xml version="1.0"?>'
      xml_body = PDCSerialization::Datacite.new_from_work_resource(self).to_xml
      xml_declaration + "\n" + xml_body + "\n"
    end

    class << self
      # Creates a PDCMetadata::Resource from a JSONB postgres field
      #  This jsonb_hash can be created by running JSON.parse(pdc_metadata_resource.to_json)
      #   or by loading it from the work.metadata jsonb field
      def new_from_jsonb(jsonb_hash)
        resource = PDCMetadata::Resource.new
        return resource if jsonb_hash.blank?

        set_basics(resource, jsonb_hash)
        set_curator_controlled_metadata(resource, jsonb_hash)
        set_additional_metadata(resource, jsonb_hash)
        set_titles(resource, jsonb_hash)
        set_creators(resource, jsonb_hash)
        set_individual_contributors(resource, jsonb_hash)
        set_organization_contributors(resource, jsonb_hash)
        set_related_objects(resource, jsonb_hash)
        set_funders(resource, jsonb_hash)

        resource
      end

      def resource_type_general_values
        Datacite::Mapping::ResourceTypeGeneral.map(&:value)
      end

      def default_resource_type_general
        "Dataset"
      end

      private

        def rights(form_rights)
          PDCMetadata::Rights.find(form_rights["identifier"]) if form_rights
        end

        def set_basics(resource, hash)
          resource.description = hash["description"]
          resource.publisher = hash["publisher"]
          resource.publication_year = hash["publication_year"]
          resource.rights = rights(hash["rights"])
        end

        def set_curator_controlled_metadata(resource, hash)
          resource.doi = hash["doi"]
          resource.ark = hash["ark"]
          resource.version_number = hash["version_number"]
          resource.collection_tags = hash["collection_tags"] || []
          resource.resource_type = hash["resource_type"]

          # TODO: Older records have a different format.
          # When we migrate these, then this can be removed.
          resource_type_general = hash["resource_type_general"]
          unless resource_type_general.blank? || Datacite::Mapping::ResourceTypeGeneral.find_by_value(resource_type_general)
            resource_type_general = ::Datacite::Mapping::ResourceTypeGeneral.find do |obj|
              ::PDCMetadata.fuzzy_match(obj, resource_type_general)
            end.value
          end
          resource.resource_type_general = resource_type_general
        end

        def set_additional_metadata(resource, hash)
          resource.keywords = hash["keywords"] || []
        end

        def set_titles(resource, hash)
          titles = hash["titles"] || []

          titles.each do |title|
            resource.titles << PDCMetadata::Title.new(title: title["title"], title_type: title["title_type"])
          end
        end

        def set_related_objects(resource, hash)
          related_objects = hash["related_objects"] || []

          related_objects.each do |related_object|
            next if related_object["related_identifier"].blank? && related_object["related_identifier_type"].blank?
            resource.related_objects << PDCMetadata::RelatedObject.new(
                                          related_identifier: related_object["related_identifier"],
                                          related_identifier_type: related_object["related_identifier_type"],
                                          relation_type: related_object["relation_type"]
                                        )
          end
        end

        def set_creators(resource, hash)
          creators = hash["creators"] || []

          creators.each do |creator|
            resource.creators << Creator.from_hash(creator)
          end
          resource.creators.sort_by!(&:sequence)
        end

        def set_individual_contributors(resource, hash)
          individual_contributors = hash["contributors"] || []

          individual_contributors.each do |contributor|
            resource.individual_contributors << Creator.contributor_from_hash(contributor)
          end
          resource.individual_contributors.sort_by!(&:sequence)
        end

        def set_organizational_contributors(resource, hash)
          organizational_contributors = hash["organizational_contributors"] || []

          organizational_contributors.each do |contributor|
            resource.organizational_contributors << Creator.contributor_from_hash(contributor)
          end
          # TODO: resource.organizational_contributors.sort_by!(&:sequence)
        end

        def set_funders(resource, hash)
          funders = hash["funders"] || []

          funders.each do |funder|
            resource.funders << Funder.funder_from_hash(funder)
          end
          # TODO: Make funders reorderable
          # resource.funders.sort_by!(&:sequence)
        end
    end
  end
end
