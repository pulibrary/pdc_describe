# frozen_string_literal: true
require "rails_helper"

RSpec.describe PDCMetadata::Resource, type: :model do
  let(:creatorPerson) do
    PDCMetadata::Creator.new_person("Elizabeth", "Miller", "1234-5678-9012-1234")
  end

  let(:creatorOrganization) do
    org = PDCMetadata::Creator.new(value: "Princeton University", name_type: "Organization")
    org.affiliations << PDCMetadata::Affiliation.new(value: "Some affiliation", identifier: "https://ror.org/04aj4c181", scheme: "ROR", scheme_uri: "https://ror.org/")
    org
  end

  let(:ds) do
    ds = described_class.new(doi: "10.5072/example-full", title: "hello world")
    ds.description = "this is an example description"
    ds.creators = [creatorPerson, creatorOrganization]
    ds
  end

  it "handles basic fields" do
    expect(ds.identifier).to eq "10.5072/example-full"
    expect(ds.main_title).to eq "hello world"
    expect(ds.resource_type).to eq "Dataset"
    expect(ds.creators.count).to be 2
    expect(ds.creators.first.affiliations.count).to be 0
    expect(ds.creators.second.affiliations.count).to be 1
  end

  it "supports more than one title" do
    ds.titles << PDCMetadata::Title.new(title: "hola mundo", title_type: "TranslatedTitle")
    expect(ds.titles.count).to be 2
  end

  it "serializes to xml" do
    # Eventually we might want to support a complete example like this
    # https://schema.datacite.org/meta/kernel-4.4/example/datacite-example-full-v4.xml
    expect(ds.to_xml).to eq(file_fixture("datacite_basic.xml").read)
  end

  it "handles ORCID values" do
    expect(creatorPerson.orcid).to eq "1234-5678-9012-1234"
    expect(creatorPerson.orcid_url).to eq "https://orcid.org/1234-5678-9012-1234"

    no_orcid = PDCMetadata::Creator.new_person("Elizabeth", "Miller")
    expect(no_orcid.orcid).to be nil
  end

  it "creates the expected json" do
    work = FactoryBot.create(:shakespeare_and_company_work)
    expect(work.metadata).to eq(work.to_json)
  end
end
