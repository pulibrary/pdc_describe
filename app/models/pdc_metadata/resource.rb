# frozen_string_literal: true
module PDCMetadata
  # Represents a PUL Datacite resource
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  #
  class Resource
    attr_accessor :creators, :titles, :publisher, :publication_year, :resource_type, :resource_type_general,
      :description, :doi, :ark, :rights, :version_number, :collection_tags, :keywords, :contributors, :related_objects,
      :funder_name, :award_number, :award_uri

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
      @funder_name = nil
      @award_number = nil
      @award_uri = nil
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

        set_basics(resource, hash)
        set_curator_controlled_metadata(resource, hash)
        set_additional_metadata(resource, hash)
        set_titles(resource, hash)
        set_creators(resource, hash)
        set_contributors(resource, hash)
        set_related_objects(resource, hash)

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
          resource.resource_type_general = hash["resource_type_general"]&.to_sym
        end

        def set_additional_metadata(resource, hash)
          resource.keywords = hash["keywords"] || []
          resource.funder_name = hash["funder_name"]
          resource.award_number = hash["award_number"]
          resource.award_uri = hash["award_uri"]
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

        def set_contributors(resource, hash)
          contributors = hash["contributors"] || []

          contributors.each do |contributor|
            resource.contributors << Creator.contributor_from_hash(contributor)
          end
          resource.contributors.sort_by!(&:sequence)
        end
    end
  end
end
