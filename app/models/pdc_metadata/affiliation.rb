# frozen_string_literal: true
# Class for storing an affiliation in our local representation
module PDCMetadata
  # value:      "datacite"
  # identifier: "https://ror.org/04aj4c181"
  # scheme:     "ROR"
  # scheme_uri: "https://ror.org/"
  class Affiliation
    attr_accessor :value, :identifier, :scheme, :scheme_uri
    def initialize(value: nil, identifier: nil, scheme: nil, scheme_uri: nil)
      @value = value
      @identifier = identifier
      @scheme = scheme
      @scheme_uri = scheme_uri
    end

    def datacite_attributes
      {
        value:,
        identifier:,
        identifier_scheme: scheme,
        scheme_uri:
      }
    end

    def compare_value
      "[#{scheme}:#{value}(#{scheme_uri})](#{identifier})"
    end

    def self.new_affiliation(value:, ror: nil)
      scheme = nil
      identifier = nil
      if ror.present?
        scheme = "ROR"
        identifier = ror
      end
      new(value:, scheme:, identifier:, scheme_uri: nil)
    end
  end
end
