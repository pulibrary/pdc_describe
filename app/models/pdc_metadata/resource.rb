# frozen_string_literal: true
module PDCMetadata
  # Represents a PUL Datacite resource
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  #
  class Resource
    attr_accessor :creators, :titles, :publisher, :publication_year, :resource_type, :resource_type_general,
      :description, :doi, :ark, :rights, :version_number, :collection_tags, :keywords, :contributors, :related_objects

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
      @contributors = []
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
      # Creates a PDCMetadata::Resource from a JSON string
      def new_from_json(json_string)
        resource = PDCMetadata::Resource.new
        return resource if json_string.blank?

        hash = JSON.parse(json_string)

        resource = curator_controlled_metadata(hash, resource)

        resource.description = hash["description"]
        titles_from_json(resource, hash["titles"])
        creators_from_json(resource, hash["creators"])
        contributors_from_json(resource, hash["contributors"])
        related_objects_from_json(resource, hash["related_objects"])
        resource.publisher = hash["publisher"]
        resource.publication_year = hash["publication_year"]
        resource.rights = rights(hash["rights"])
        resource.keywords = hash["keywords"] || []

        resource
      end

      def resource_type_general_options
        pairs = Datacite::Mapping::ResourceTypeGeneral.to_a.map { |value| [value.key, value.value] }
        built = Hash[pairs]
        built.with_indifferent_access
      end

      def default_resource_type_general
        :DATASET
      end

      private

        def curator_controlled_metadata(hash, resource)
          resource.doi = hash["doi"]
          resource.ark = hash["ark"]
          resource.version_number = hash["version_number"]
          resource.collection_tags = collection_tags(hash["collection_tags"])
          resource.resource_type = hash["resource_type"]
          resource.resource_type_general = hash["resource_type_general"]&.to_sym
          resource
        end

        def rights(form_rights)
          PDCMetadata::Rights.find(form_rights["identifier"]) if form_rights
        end

        def collection_tags(form_tags)
          form_tags || []
        end

        def titles_from_json(resource, titles)
          return if titles.blank?

          titles.each do |title|
            resource.titles << PDCMetadata::Title.new(title: title["title"], title_type: title["title_type"])
          end
        end

        def related_objects_from_json(resource, related_objects)
          return if related_objects.blank?
          related_objects.each do |related_object|
            resource.related_objects << PDCMetadata::RelatedObject.new(
                                          related_identifier: related_object["related_identifier"],
                                          related_identifier_type: related_object["related_identifier_type"],
                                          relation_type: related_object["relation_type"]
                                        )
          end
        end

        def creators_from_json(resource, creators)
          return if creators.blank?

          creators.each do |creator|
            resource.creators << Creator.from_hash(creator)
          end
          resource.creators.sort_by!(&:sequence)
        end

        def contributors_from_json(resource, contributors)
          return if contributors.blank?

          contributors.each do |contributor|
            resource.contributors << Creator.contributor_from_hash(contributor)
          end
          resource.contributors.sort_by!(&:sequence)
        end
    end
  end
end
