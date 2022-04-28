# frozen_string_literal: true
require "faraday"

class DspaceImportService
  class MetadataDocument
    attr_reader :attributes

    def initialize(document)
      @document = document
      @attributes = {}

      self.class.attribute_xpaths.each_pair do |attr, xpath|
        elements = dc_element.xpath(xpath, self.class.namespaces)
        attributes[attr] = elements.map(&:content)
      end
    end

    def dc_element
      @dc_element ||= root.at_xpath("./oai:GetRecord/oai:record/oai:metadata/oai_dc:dc", self.class.namespaces)
    end

    delegate :each_pair, to: :attributes
    delegate :root, to: :@document

    def self.namespaces
      {
        oai: "http://www.openarchives.org/OAI/2.0/",
        oai_dc: "http://www.openarchives.org/OAI/2.0/oai_dc/",
        dc: "http://purl.org/dc/elements/1.1/"
      }
    end

    def self.attribute_xpaths
      {
        title: "./dc:title",
        creator: "./dc:creator",
        subject: "./dc:subject",
        date: "./dc:date",
        identifier: "./dc:identifier",
        language: "./dc:language",
        relation: "./dc:relation",
        publisher: "./dc:publisher"
      }
    end
  end

  class Metadata
    attr_reader :document, :attributes

    def self.from_xml(source)
      document = MetadataDocument.new(source)
      metadata = new
      document.attributes.each_pair do |key, value|
        metadata[key] = value
      end

      metadata
    end

    def initialize(attributes: {})
      @attributes = attributes

      self.class.define_attribute_methods
    end

    delegate :each_pair, to: :attributes

    def read_attribute(value)
      send(value.to_sym)
    end

    def []=(key, value)
      send("#{key}=".to_sym, value)
    end

    def self.attribute_names
      [
        :title,
        :creator,
        :subject,
        :date,
        :identifier,
        :language,
        :relation,
        :publisher
      ]
    end

    def self.define_attribute_methods
      attribute_names.each do |attr_name|
        define_method attr_name.to_sym do |*_args|
          attributes[attr_name]
        end

        define_method "#{attr_name}=".to_sym do |*args|
          value = args.shift
          attributes[attr_name] = value
        end
      end
    end
  end

  class DublinCoreMetadata < Metadata
    def self.attribute_names
      super.merge([
                    :title
                  ])
    end
  end

  attr_reader :url, :collection, :user, :work_type

  def initialize(url:, user:, collection:, work_type: nil)
    @url = url
    @user = user
    @collection = collection
    @work_type = work_type
  end

  def metadata
    @metadata ||= Metadata.from_xml(document)
  end

  delegate :title, to: :metadata

  def import!
    request!

    metadata.each_pair do |attr, value|
      attr_type = Work.attribute_types[attr.to_s]
      if value.is_a?(Enumerable) && attr_type.is_a?(ActiveModel::Type::String)
        Rails.logger.warn("The value for the attribute `#{attr}` is an enumerable, but the Work Model defines this only for scalar string values. Importing only the first value into the attribute.")
        work.write_attribute(attr, value.first)
      else
        work.write_attribute(attr, value)
      end
    rescue ActiveModel::MissingAttributeError
      # raise(NotImplementedError, "Failed to import the attribute `#{attr}`: This attribute is not defined on the Work Model.")
      Rails.logger.warn("Failed to import the attribute `#{attr}`: This attribute is not defined on the Work Model.")
    end

    work
  end

  def work
    @work ||= Work.create_skeleton(title, user.id, collection.id, work_type)
  end

  private

    def client
      Faraday.new(
        url: url,
        params: {},
        headers: {
          "Content-Type" => "application/xml"
        }
      )
    end

    def request!
      # @response ||= client.get(@url)
      @response ||= client.get
    end

    def document
      Nokogiri::XML.parse(@response.body)
    end
end
