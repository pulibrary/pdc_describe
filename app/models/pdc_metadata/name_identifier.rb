# frozen_string_literal: true
# Class for storing a named identifier for the creator in our local representation.  This identifier can be a person or organization.
# **Please Note:**
# The class name NameIdentifier is being utilized becuase it matches with the DataCite Schema: https://support.datacite.org/docs/datacite-metadata-schema-v44-mandatory-properties#24-nameidentifier
# It also matches with the DataCite xml mapping gem that we are utilizing: https://github.com/CDLUC3/datacite-mapping/blob/master/lib/datacite/mapping/name_identifier.rb
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
      "#{scheme_uri}/#{value}"
    end

    def orcid
      return nil unless scheme == ORCID
      value
    end

    def ror
      ror_url
    end

    # Allow override of where to look up ROR values.
    # This lets us test ROR behavior without making network calls.
    # See spec/support/orcid_specs.rb for more info
    def ror_url
      return nil unless scheme == ROR

      value
    end

    def ror_id
      return nil unless scheme == ROR
      value.split("/").last
    end

    def self.new_orcid(value)
      NameIdentifier.new(value:, scheme: ORCID, scheme_uri: "https://orcid.org")
    end

    def self.new_ror(value)
      NameIdentifier.new(value:, scheme: ROR, scheme_uri: "https://ror.org")
    end
  end
end
