# frozen_string_literal: true
# Class for representing a Rights statement
module PDCMetadata
  class Rights
    attr_accessor :identifier, :uri, :name
    def initialize(identifier:, uri:, name:)
      @identifier = identifier
      @uri = uri
      @name = name
    end

    def self.all
      @all ||= begin
        [
          PDCMetadata::Rights.new(identifier: "CC0 1.0", uri: "https://creativecommons.org/publicdomain/zero/1.0/", name: "Creative Commons 1"),
          PDCMetadata::Rights.new(identifier: "CC0 2.0", uri: "https://creativecommons.org/publicdomain/zero/1.0/", name: "Creative Commons 2")
        ]
      end
    end

    def self.find(identifier)
      all.find { |rights| rights.identifier == identifier}
    end
  end
end
