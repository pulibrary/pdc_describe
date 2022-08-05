# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDatacite::Resource, type: :model do
  context "create a datacite record through a form submission" do
    let(:doi) { "https://doi.org/10.34770/pe9w-x904" }
    let(:form_submission_data) do
      {
        "identifier": doi,
        "identifier_type": "DOI",
        "titles": [{ "title": "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events", "title_type": "Main" }],
        "description": "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
        "creators": [
          { "value": "Kotin, Joshua", "name_type": "Personal", "given_name": "Joshua", "family_name": "Kotin", "affiliations": [], "sequence": "1" }
        ],
        "resource_type": "Dataset",
        "publisher": "Princeton University",
        "publication_year": "2020"
      }.to_json
    end
    let(:ds) { described_class.new_from_json(form_submission_data) }
    let(:mapping) { ds.datacite_mapping }
    let(:datacite_xml) { ds.to_xml }

    context "datacite xml" do
      it "has a doi" do
        expect(mapping.identifier).to be_instance_of Datacite::Mapping::Identifier
        expect(mapping.identifier.value).to eq doi
        expect(mapping.identifier.identifier_type).to eq "DOI"
      end

      it "has a title" do
        expect(mapping.titles.first.value).to eq "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events"
      end

      it "has a creator" do
        expect(mapping.creators.first.creator_name.value).to eq "Kotin, Joshua"
      end

      it "has a resource type" do
        expect(mapping.resource_type.resource_type_general.value).to eq "Dataset"
      end

      it "has a publisher" do
        expect(mapping.publisher.value).to eq "Princeton University"
      end

      it "has a publication year" do
        expect(mapping.publication_year).to eq 2020
      end
    end
  end
end
