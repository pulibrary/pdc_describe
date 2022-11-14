# frozen_string_literal: true
require "rails_helper"

RSpec.describe PDCMetadata::RelatedObject, type: :model do
  let(:related_identifier) { "https://www.biorxiv.org/content/10.1101/545517v1" }
  let(:related_identifier_type) { "arXiv" }
  let(:relation_type) { "IsCitedBy" }

  it "#new_related_object" do
    new_related_object = described_class.new_related_object(related_identifier, related_identifier_type, relation_type)
    expect(new_related_object.value).to eq related_identifier
  end

  ##
  # Generate a list of valid options for the related_identifier_type field
  it "#related_identifier_type_options" do
    related_identifier_type_options = described_class.related_identifier_type_options.values
    expect(related_identifier_type_options).to include "ISBN"
    expect(related_identifier_type_options).to include "w3id"
    expect(related_identifier_type_options.count).to eq 19
  end

  ##
  # Generate a list of valid options for the relation_type field
  it "#relation_type" do
    relation_type_type_options = described_class.relation_type_options.values
    expect(relation_type_type_options).to include "IsVariantFormOf"
    expect(relation_type_type_options).to include "IsDerivedFrom"
    expect(relation_type_type_options.count).to eq 33
  end

  describe "#valid?" do
    let(:related_object) { described_class.new_related_object(related_identifier, related_identifier_type, relation_type) }

    it "is valid" do
      expect(related_object).to be_valid
    end

    context "identifier is not set" do
      let(:related_identifier) { nil }

      it "is invalid" do
        expect(related_object).not_to be_valid
        expect(related_object.errors).to eq(["Related identifier is missing"])
      end
    end

    context "identifier type is not set" do
      let(:related_identifier_type) { nil }

      it "is invalid" do
        expect(related_object).not_to be_valid
        expect(related_object.errors).to eq(["Related Identifier Type is missing or invalid for https://www.biorxiv.org/content/10.1101/545517v1"])
      end
    end

    context "relation type is not set" do
      let(:relation_type) { nil }

      it "is invalid" do
        expect(related_object).not_to be_valid
        expect(related_object.errors).to eq(["Relationship Type is missing or invalid for https://www.biorxiv.org/content/10.1101/545517v1"])
      end
    end
  end
end
