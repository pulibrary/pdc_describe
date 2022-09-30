# frozen_string_literal: true
module PDCMetadata
  # Represents a PUL Datacite resource
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  #
  class Resource
    attr_accessor :creators, :titles, :publisher, :publication_year, :resource_type,
      :description, :doi, :ark, :rights, :version_number

    def initialize(doi: nil, title: nil, resource_type: nil, creators: [], description: nil)
      @titles = []
      @titles << PDCMetadata::Title.new(title: title) unless title.nil?
      @description = description
      @creators = creators
      @resource_type = resource_type || "Dataset"
      @publisher = "Princeton University"
      @publication_year = Time.zone.today.year
      @ark = nil
      @doi = doi
      @rights = nil
      @version_number = "1"
    end

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
        hash = json_string.blank? ? {} : JSON.parse(json_string)

        resource.doi = hash["doi"]
        resource.ark = hash["ark"]
        resource.version_number = hash["version_number"]
        resource.description = hash["description"]

        hash["titles"]&.each do |title|
          resource.titles << PDCMetadata::Title.new(title: title["title"], title_type: title["title_type"])
        end

        creators_from_json(resource, hash["creators"])
        resource.publisher = hash["publisher"]
        resource.publication_year = hash["publication_year"]
        resource.rights = PDCMetadata::Rights.find(hash["rights"]["identifier"]) if hash["rights"]

        resource
      end

      private

        def creators_from_json(resource, creators)
          return if creators.blank?

          creators.each do |creator|
            resource.creators << Creator.from_hash(creator)
          end
          resource.creators.sort_by!(&:sequence)
        end
    end
  end
end
