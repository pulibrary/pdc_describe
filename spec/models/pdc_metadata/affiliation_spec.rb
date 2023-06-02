# frozen_string_literal: true
require "rails_helper"

describe PDCMetadata::Affiliation, type: :model do
  subject(:affiliation) do
    described_class.new(
      value: value,
      identifier: identifier,
      scheme: scheme,
      scheme_uri: scheme_uri
    )
  end

  let(:value) { "datacite" }
  let(:identifier) { "https://ror.org/04aj4c181" }
  let(:scheme) { "ROR" }
  let(:scheme_uri) { "https://ror.org/" }

  describe "#value" do
    it "accesses the value of Affiliation" do
      expect(affiliation.value).to eq(value)
    end
  end

  describe "#identifier" do
    it "accesses the identifier of Affiliation" do
      expect(affiliation.identifier).to eq(identifier)
    end
  end

  describe "#scheme" do
    it "accesses the scheme of Affiliation" do
      expect(affiliation.scheme).to eq(scheme)
    end
  end

  describe "#scheme_uri" do
    it "accesses the scheme_uri of Affiliation" do
      expect(affiliation.scheme_uri).to eq(scheme_uri)
    end
  end

  describe "#new_affiliation" do
    it "creates an affiliation with justa value" do
      affiliation = described_class.new_affiliation(value: "Princeton")
      expect(affiliation.value).to eq("Princeton")
      expect(affiliation.identifier).to be_nil
      expect(affiliation.scheme).to be_nil
      expect(affiliation.scheme_uri).to be_nil
    end

    it "sets the right scheme if an ROR is present" do
      affiliation = described_class.new_affiliation(value: "Princeton", ror: "https://ror.org/00hx57361")
      expect(affiliation.value).to eq("Princeton")
      expect(affiliation.identifier).to eq("https://ror.org/00hx57361")
      expect(affiliation.scheme).to eq("ROR")
      expect(affiliation.scheme_uri).to be_nil
    end
  end
end
