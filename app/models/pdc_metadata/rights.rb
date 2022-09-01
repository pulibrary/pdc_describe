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
      @all ||= [
        Rights.new(identifier: "CC BY", uri: "https://creativecommons.org/licenses/by/4.0/", name: "Creative Commons Attribution 4.0 International"),
        Rights.new(identifier: "CC BY-SA", uri: "https://creativecommons.org/licenses/by-sa/4.0/", name: "Creative Commons Attribution-ShareAlike 4.0 International"),
        Rights.new(identifier: "CC BY-NC", uri: "https://creativecommons.org/licenses/by-nc/4.0/", name: "Creative Commons Attribution-NonCommercial 4.0 International"),
        Rights.new(identifier: "CC BY-NC-SA", uri: "https://creativecommons.org/licenses/by-nc-sa/4.0/", name: "Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International"),
        Rights.new(identifier: "CC BY-ND", uri: "https://creativecommons.org/licenses/by-nd/4.0/", name: "Creative Commons Attribution-NoDerivatives 4.0 International"),
        Rights.new(identifier: "CC BY-NC-ND", uri: "https://creativecommons.org/licenses/by-nc-nd/4.0/", name: "Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International"),
        Rights.new(identifier: "CC0", uri: "https://creativecommons.org/publicdomain/zero/1.0/", name: "Creative Commons 1.0 Universal - Public Domain Dedication")
      ]
    end

    def self.find(identifier)
      all.find { |rights| rights.identifier == identifier }
    end
  end
end
