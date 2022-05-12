# frozen_string_literal: true
module Datacite
  # Represents a Datacite resource
  # https://support.datacite.org/docs/datacite-metadata-schema-v44-properties-overview
  class Resource
    attr_accessor :identifier, :identifier_type, :creators, :titles, :publisher, :publication_year, :resource_type

    def initialize(identifier: nil, identifier_type: nil, title: nil, resource_type: nil)
      @identifier = identifier
      @identifier_type = identifier_type
      @titles = []
      @titles << Datacite::Title.new(title: title) unless title.nil?
      @creators = []
      @resource_type = resource_type || "Dataset"
    end

    def title
      @titles.first&.title
    end

    # rubocop:disable Metrics/MethodLength
    def to_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.resource("xsi:schemaLocation" => "http://datacite.org/schema/kernel-4 https://schema.datacite.org/meta/kernel-4.4/metadata.xsd") do
          xml.identifier("identifierType" => @identifier_type) do
            xml.text @identifier
          end
          xml.creators do
            @creators.each do |creator|
              if creator.name_type == "Personal"
                xml.creator("nameType" => "Personal") do
                  xml.creatorName creator.value
                  xml.givenName creator.given_name
                  xml.familyName creator.family_name
                end
              else
                xml.creator("nameType" => "Organization") do
                  xml.creatorName creator.value
                end
              end
            end
          end
        end
      end
      builder.to_xml
    end
    # rubocop:enable Metrics/MethodLength

    # Creates a Datacite::Resource from a JSON string
    def self.new_from_json_string(json_string)
      resource = Datacite::Resource.new
      hash = json_string.blank? ? {} : JSON.parse(json_string)
      hash["titles"]&.each do |title|
        resource.titles << Datacite::Title.new(title: title["title"], title_type: title["title_type"])
      end
      hash["creators"]&.each do |creator|
        orcid = creator.dig("name_identifier", "scheme") == "ORCID" ? creator.dig("name_identifier", "value") : nil
        resource.creators << Datacite::Creator.new_person(creator["given_name"], creator["family_name"], orcid)
      end
      resource
    end
  end

  # value: "Miller, Elizabeth"
  # name_type: "Personal"
  # given_name: "Elizabeth"
  # family_name: "Miller"
  class Creator
    attr_accessor :value, :name_type, :given_name, :family_name, :name_identifier, :affiliations

    def initialize(value: nil, name_type: nil, given_name: nil, family_name: nil, name_identifier: nil)
      @value = value
      @name_type = name_type
      @given_name = given_name
      @family_name = family_name
      @name_identifier = name_identifier
      @affiliations = []
    end

    def orcid_url
      name_identifier&.orcid_url
    end

    def orcid
      name_identifier&.orcid
    end

    def self.new_person(given_name, family_name, orcid_id = nil)
      full_name = "#{given_name}, #{family_name}"
      creator = Creator.new(value: full_name, name_type: "Personal", given_name: given_name, family_name: family_name)
      if orcid_id.present?
        creator.name_identifier = NameIdentifier.new_orcid(orcid_id)
      end
      creator
    end
  end

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

    def orcid_url
      return nil unless scheme == "ORCID"
      "#{scheme_uri}/#{value}"
    end

    def orcid
      return nil unless scheme == "ORCID"
      value
    end

    # Convenience method since this is the most common (only?) identifier that we are currently supporting
    def self.new_orcid(value)
      NameIdentifier.new(value: value, scheme: "ORCID", scheme_uri: "http://orcid.org")
    end
  end

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
  end

  # value:      "100 años de soledad"
  # title_type: "TranslatedTitle"
  class Title
    attr_accessor :title, :title_type
    def initialize(title:, title_type: nil)
      @title = title
      @title_type = title_type
    end

    def main?
      @title_type.blank?
    end

    def alternative?
      @title_type == "AlternativeTitle"
    end

    def self.title_types
      t1 = OpenStruct.new(id: "AlternativeTitle", value: "Alternative Title")
      t2 = OpenStruct.new(id: "Subtitle", value: "Subtitle")
      t3 = OpenStruct.new(id: "TranslatedTitle", value: "Translated Title")
      t4 = OpenStruct.new(id: "Other", value: "Other")
      [t1, t2, t3, t4]
    end
  end
end
