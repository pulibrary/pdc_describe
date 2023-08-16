# frozen_string_literal: true
require "rails_helper"

RSpec.describe PDCMetadata::Creator, type: :model do
  let(:first_name) { "Elizabeth" }
  let(:last_name) { "Miller" }
  let(:orcid) { "1234-5678-9012-1234" }

  describe "#new_person" do
    it "allows a new person to be created" do
      new_person = described_class.new_person(first_name, last_name, orcid)
      expect(new_person.value).to eq "Miller, Elizabeth"
    end

    it "allows a new person to be created with ror and affiliation" do
      new_person = described_class.new_person(first_name, last_name, orcid, ror: "http://example.com", affiliation: "Example")
      expect(new_person.value).to eq "Miller, Elizabeth"
      expect(new_person.affiliations.count).to eq(1)
      expect(new_person.affiliations.map(&:value)).to eq(["Example"])
      expect(new_person.affiliations.map(&:identifier)).to eq(["http://example.com"])
      expect(new_person.affiliations.map(&:scheme)).to eq(["ROR"])
    end

    it "strips spaces from names" do
      new_person = described_class.new_person("Saul", " Hernandez ", orcid)
      expect(new_person.given_name).to eq "Saul"
      expect(new_person.family_name).to eq "Hernandez"
      expect(new_person.value).to eq "Hernandez, Saul"
    end
  end

  it "allows affilitation to be set" do
    creator = described_class.new(affiliations: [PDCMetadata::Affiliation.new(value: "Princeton")])
    expect(creator.affiliations.map(&:value)).to eq(["Princeton"])
  end
end
