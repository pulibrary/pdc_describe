# frozen_string_literal: true

module Metadata
  class OaiPmhDocument < Document
    def initialize(document)
      super(document)

      self.class.attribute_xpaths.each_pair do |attr, xpath|
        elements = dc_element.xpath(xpath, self.class.namespaces)
        attributes[attr] = elements.map(&:content)
      end
    end

    def oai_get_record
      @oai_get_record ||= root.at_xpath("./oai:GetRecord", self.class.namespaces)
    end

    def oai_record
      @oai_record ||= oai_get_record.at_xpath("./oai:record", self.class.namespaces)
    end

    def oai_metadata
      @oai_metadata ||= oai_record.at_xpath("./oai:metadata", self.class.namespaces)
    end

    def dc_element
      @dc_element ||= oai_metadata.at_xpath("./oai_dc:dc", self.class.namespaces)
    end

    def self.namespaces
      super.merge({
                    oai: "http://www.openarchives.org/OAI/2.0/",
                    oai_dc: "http://www.openarchives.org/OAI/2.0/oai_dc/",
                    dc: "http://purl.org/dc/elements/1.1/"
                  })
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
end
