# frozen_string_literal: true

module Metadata
  class Document
    attr_reader :attributes

    def initialize(document)
      @document = document
      @attributes = {}

      self.class.attribute_xpaths.each_pair do |attr, xpath|
        elements = root.xpath(xpath, self.class.namespaces)
        attributes[attr] = elements.map(&:content)
      end
    end

    delegate :each_pair, to: :attributes
    delegate :root, to: :@document

    def self.namespaces
      {}
    end

    def self.attribute_xpaths
      {}
    end
  end
end
