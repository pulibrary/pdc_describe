# frozen_string_literal: true
# Class for storing a named identifier for the creator in our local representation.  This identifier can be a person or organization.
# **Please Note:**
# The class name NameIdentifier is being utilized becuase it matches with the DataCite Schema: https://support.datacite.org/docs/datacite-metadata-schema-v44-mandatory-properties#24-nameidentifier
# It also matches with the DaCite xml mapping gem that we are utilizing: https://github.com/CDLUC3/datacite-mapping/blob/master/lib/datacite/mapping/name_identifier.rb
module PDCMetadata
  # value:      "0000-0001-5000-0007"
  # scheme:     "ORCID"
  # scheme_uri: "https://orcid.org/""
  class NameIdentifier
    attr_accessor :value, :scheme, :scheme_uri
    def initialize(value: nil, scheme: nil, scheme_uri: nil)
      @value = value
      @scheme = scheme
      @scheme_uri = scheme_uri
    end

    ORCID = "ORCID"
    ROR = "ROR"

    def orcid_url
      return nil unless scheme == ORCID
      url
    end

    def orcid
      return nil unless scheme == ORCID
      value
    end

    def ror_url
      return nil unless scheme == ROR
      url
    end

    def ror
      return nil unless scheme == ROR
      value
    end

    def self.new_orcid(value)
      NameIdentifier.new(value: value, scheme: "ORCID", scheme_uri: "https://orcid.org")
    end

    def self.new_ror(value)
      NameIdentifier.new(value: value, scheme: "ROR", scheme_uri: "https://ror.org")
    end

    private

      def url
        "#{scheme_uri}/#{value}"
      end
  end
end
