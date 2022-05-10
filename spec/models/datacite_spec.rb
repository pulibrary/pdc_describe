# frozen_string_literal: true
require "rails_helper"

RSpec.describe Datacite::Resource, type: :model do
  let(:creatorPerson) do
    Datacite::Creator.new(value: "Miller, Elizabeth", name_type: "Personal", given_name: "Elizabeth", family_name: "Miller")
  end

  let(:creatorOrganization) do
    org = Datacite::Creator.new(value: "Princeton University", name_type: "Organization")
    org.affiliations << Datacite::Affiliation.new(value: "Some affiliation", identifier: "https://ror.org/04aj4c181", scheme: "ROR", scheme_uri: "https://ror.org/")
    org
  end

  let(:ds) do
    ds = described_class.new(identifier: "10.5072/example-full", identifier_type: "DOI", title: "hello world")
    ds.creators = [creatorPerson, creatorOrganization]
    ds
  end

  it "handles basic fields" do
    expect(ds.identifier).to eq "10.5072/example-full"
    expect(ds.title).to eq "hello world"
    expect(ds.resource_type).to eq "Dataset"
    expect(ds.creators.count).to be 2
    expect(ds.creators.first.affiliations.count).to be 0
    expect(ds.creators.second.affiliations.count).to be 1
  end

  it "supports more than one title" do
    ds.titles << Datacite::Title.new(title: "hola mundo", title_type: "TranslatedTitle")
    expect(ds.titles.count).to be 2
  end

  it "serializes to xml" do
    # Eventually we might want to support a complete example like this
    # https://schema.datacite.org/meta/kernel-4.4/example/datacite-example-full-v4.xml
    expect(ds.to_xml).to eq(file_fixture("datacite_basic.xml").read)
  end
end
