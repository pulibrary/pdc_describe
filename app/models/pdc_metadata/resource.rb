# frozen_string_literal: true
module PDCMetadata
  # Represents a PUL Datacite resource
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  #
  class Resource
    attr_accessor :creators, :titles, :publisher, :publication_year, :resource_type,
      :description, :doi, :ark

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

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/BlockLength
    # rubocop:disable Metrics/AbcSize
    def to_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.resource(
          "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
          "xmlns" => "http://datacite.org/schema/kernel-4",
          "xsi:schemaLocation" => "http://datacite.org/schema/kernel-4 https://schema.datacite.org/meta/kernel-4.4/metadata.xsd"
        ) do
          xml.identifier("identifierType" => identifier_type) do
            xml.text identifier
          end
          xml.titles do
            @titles.each do |title|
              if title.main?
                xml.title do
                  xml.text title.title
                end
              else
                xml.title("titleType" => title.title_type) do
                  xml.text title.title
                end
              end
            end
          end
          xml.description("descriptionType" => "Other") do
            xml.text @description
          end
          xml.creators do
            @creators.each do |creator|
              creator.to_xml(xml)
            end
          end
          xml.publisher do
            xml.text @publisher
          end
          xml.publicationYear do
            xml.text @publication_year
          end
        end
      end
      builder.to_xml
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/BlockLength
    # rubocop:enable Metrics/AbcSize

    class << self
      # Creates a PDCMetadata::Resource from a JSON string
      def new_from_json(json_string)
        resource = PDCMetadata::Resource.new
        hash = json_string.blank? ? {} : JSON.parse(json_string)

        resource.doi = hash["doi"]
        resource.ark = hash["ark"]
        resource.description = hash["description"]

        hash["titles"]&.each do |title|
          resource.titles << PDCMetadata::Title.new(title: title["title"], title_type: title["title_type"])
        end

        creators_from_json(resource, hash["creators"])
        resource.publisher = hash["publisher"]
        resource.publication_year = hash["publication_year"]

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
