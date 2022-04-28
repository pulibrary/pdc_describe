class DSpaceImportService
  class MetadataDocument

    def initialize(document)
      @document = document
    end

    delegate :root, to: :@document

    def self.namespaces
      {
        dc: ''
      }
    end

    def self.attribute_xpaths
      {
        title: './dc:title'
      }
    end

    def find_element(value)
      attr_xpath = self.class.attribute_xpaths[value]
      root.at_xpath(attr_xpath, self.class.namespaces)
    end

    def read_attribute(value)
      element = find_element(value)
      element.content
    end

  end

  class Metadata
    attr_reader :document, :attributes

    def self.from_xml(source)
      document = MetadataDocument.new(source)
      metadata = self.new
      document.attributes.each_pair do |key, value|
        metadata[key] = value
      end

      metadata
    end

    def initialize(attributes: {})
      @attributes = attributes
    end

    def read_attribute(value)
      send(value.snake_case.to_sym)
    end

    def self.attribute_names
      [
        :title
      ]
    end

    private

    def define_attribute_methods
      self.class.attribute_names.each do |attr_name|
        define_method attr_name.to_sym do |*args|
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

  def initialize(url:, user:, collection:, work_type: nil)
    @url = url
    @user = user
    @collection = collection
    @work_type = work_type
  end

  def metadata
    @metadata ||= Metadata.new(document)
  end

  delegate :title, to: :metadata

  def import!
    metadata.each_pair do |field, value|
      work.write_attribute(field, value)
    end

    work
  end

  def work
    @work ||= Work.create_skeleton(title, user.id, collection.id, work_type)
  end

  private

  def request!
    @response ||= client.get(url)
  end

  def document
    Nokogiri::XML.parse(@response.body)
  end

end
