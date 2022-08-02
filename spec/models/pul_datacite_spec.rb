# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDatacite::Resource, type: :model do
  let(:creatorPerson) do
    PULDatacite::Creator.new_person("Elizabeth", "Miller", "1234-5678-9012-1234")
  end

  let(:creatorOrganization) do
    org = PULDatacite::Creator.new(value: "Princeton University", name_type: "Organization")
    org.affiliations << PULDatacite::Affiliation.new(value: "Some affiliation", identifier: "https://ror.org/04aj4c181", scheme: "ROR", scheme_uri: "https://ror.org/")
    org
  end

  let(:doi) { "10.5555/12345678" }

  let(:ds) do
    ds = described_class.new(identifier: doi, identifier_type: "DOI", title: "hello world")
    ds.description = "this is an example description"
    ds.creators = [creatorPerson, creatorOrganization]
    ds
  end

  it "handles basic fields" do
    expect(ds.identifier).to eq doi
    expect(ds.main_title).to eq "hello world"
    expect(ds.resource_type).to eq "Dataset"
    expect(ds.creators.count).to be 2
    expect(ds.creators.first.affiliations.count).to be 0
    expect(ds.creators.second.affiliations.count).to be 1
  end

  it "has a Datacite::Mapping::Resource" do
    expect(ds.datacite_mapping).to be_instance_of Datacite::Mapping::Resource
  end

  it "creates an array of Datacite::Mapping::Creator" do
    expect(ds.datacite_creators.class).to eq Array
    expect(ds.datacite_creators.first.class).to eq Datacite::Mapping::Creator
  end

  it "creates a Datacite::Mapping::Identifier for the DOI" do
    expect(ds.datacite_identifier.class).to eq Datacite::Mapping::Identifier
  end

  it "supports more than one title" do
    ds.titles << PULDatacite::Title.new(title: "hola mundo", title_type: "TranslatedTitle")
    expect(ds.titles.count).to be 2
  end

  it "serializes to xml" do
    # Eventually we might want to support a complete example like this
    # https://schema.datacite.org/meta/kernel-4.4/example/datacite-example-full-v4.xml
    xml_output = ds.to_xml
    dcm = Datacite::Mapping::Resource.parse_xml(xml_output)
    expect(dcm.identifier.value).to eq doi
    expect(dcm.creators.first.creator_name.value).to eq "Miller, Elizabeth"
  end

  it "handles ORCID values" do
    expect(creatorPerson.orcid).to eq "1234-5678-9012-1234"
    expect(creatorPerson.orcid_url).to eq "https://orcid.org/1234-5678-9012-1234"

    no_orcid = PULDatacite::Creator.new_person("Elizabeth", "Miller")
    expect(no_orcid.orcid).to be nil
  end
end
