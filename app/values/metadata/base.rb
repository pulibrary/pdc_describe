# frozen_string_literal: true

module Metadata
  class Base
    attr_reader :document, :attributes

    def self.document_class
      Document
    end

    def self.from_xml(source)
      document = document_class.new(source)
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

    def []=(key, value)
      send("#{key}=".to_sym, value)
    end

    def self.attribute_names
      []
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
end
