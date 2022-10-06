# frozen_string_literal: true
require "rails_helper"

RSpec.describe PDCSerialization::Datacite, type: :model do
  context "create a skeleton datacite record" do
    let(:identifier) { "10.34770/tbd" }
    let(:title) { "Skeleton In The Closet" }
    let(:creator) { "Doctor Bones" }
    let(:publisher) { "Femur Inc." }
    let(:publication_year) { 1654 }
    let(:resource_type) { "Dataset" }
    let(:skeleton_datacite_xml) do
      described_class.skeleton_datacite_xml(
      identifier: identifier,
      title: title,
      creator: creator,
      publisher: publisher,
      publication_year: publication_year,
      resource_type: resource_type
    )
    end
    let(:parsed_xml) { Datacite::Mapping::Resource.parse_xml(skeleton_datacite_xml) }
    it "outputs minimally valid xml" do
      parsed_xml
      expect(parsed_xml.identifier.value).to eq identifier
      expect(parsed_xml.titles.first.value).to eq title
      expect(parsed_xml.creators.first.creator_name.value).to eq creator
      expect(parsed_xml.publisher.value).to eq publisher
      expect(parsed_xml.publication_year).to eq publication_year
      expect(parsed_xml.resource_type.resource_type_general.value).to eq resource_type
    end
  end

  describe ".new_from_work" do
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    let(:new_resource) { described_class.new_from_work(work) }
    it "creates a new Resource from a Work" do
      expect(new_resource).to be_a(PDCSerialization::Datacite)
      expect(new_resource.mapping).to be_a(Datacite::Mapping::Resource)
      expect(new_resource.mapping.titles).not_to be_empty
      expect(new_resource.mapping.titles.first).to be_a(Datacite::Mapping::Title)
      expect(new_resource.mapping.titles.first.value).to eq("Shakespeare and Company Project Dataset: Lending Library Members, Books, Events")
    end
  end

  context "create a datacite record through a form submission" do
    let(:doi) { "https://doi.org/10.34770/pe9w-x904" }
    let(:work_resource) do
      json = {
        "doi": doi,
        "identifier_type": "DOI",
        "titles": [{ "title": "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }],
        "description": "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
        "creators": [
          { "value": "Kotin, Joshua", "name_type": "Personal", "given_name": "Joshua", "family_name": "Kotin", "affiliations": [], "sequence": "1" }
        ],
        "resource_type": "Dataset",
        "publisher": "Princeton University",
        "publication_year": "2020"
      }.to_json
      PDCMetadata::Resource.new_from_json(json)
    end
    let(:datacite) { described_class.new_from_work_resource(work_resource) }
    let(:mapping) { datacite.mapping }

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

      context "resource types" do
        it "maps dataset" do
          resource_type = described_class.datacite_resource_type("dataset")
          expect(resource_type.resource_type_general.value).to eq "Dataset"
        end
        it "Audiovisual" do
          resource_type = described_class.datacite_resource_type("Audiovisual")
          expect(resource_type.resource_type_general.value).to eq "Audiovisual"
        end
        it "Collection" do
          resource_type = described_class.datacite_resource_type("Collection")
          expect(resource_type.resource_type_general.value).to eq "Collection"
        end
        it "DataPaper" do
          resource_type = described_class.datacite_resource_type("DataPaper")
          expect(resource_type.resource_type_general.value).to eq "DataPaper"
        end
        it "Event" do
          resource_type = described_class.datacite_resource_type("Event")
          expect(resource_type.resource_type_general.value).to eq "Event"
        end
        it "Image" do
          resource_type = described_class.datacite_resource_type("Image")
          expect(resource_type.resource_type_general.value).to eq "Image"
        end
        it "InteractiveResource" do
          resource_type = described_class.datacite_resource_type("InteractiveResource")
          expect(resource_type.resource_type_general.value).to eq "InteractiveResource"
        end
        it "Model" do
          resource_type = described_class.datacite_resource_type("Model")
          expect(resource_type.resource_type_general.value).to eq "Model"
        end
        it "PhysicalObject" do
          resource_type = described_class.datacite_resource_type("PhysicalObject")
          expect(resource_type.resource_type_general.value).to eq "PhysicalObject"
        end
        it "Service" do
          resource_type = described_class.datacite_resource_type("Service")
          expect(resource_type.resource_type_general.value).to eq "Service"
        end
        it "Software" do
          resource_type = described_class.datacite_resource_type("Software")
          expect(resource_type.resource_type_general.value).to eq "Software"
        end
        it "Sound" do
          resource_type = described_class.datacite_resource_type("Sound")
          expect(resource_type.resource_type_general.value).to eq "Sound"
        end
        it "Text" do
          resource_type = described_class.datacite_resource_type("Text")
          expect(resource_type.resource_type_general.value).to eq "Text"
        end
        it "Workflow" do
          resource_type = described_class.datacite_resource_type("Workflow")
          expect(resource_type.resource_type_general.value).to eq "Workflow"
        end
        it "Other" do
          resource_type = described_class.datacite_resource_type("Other")
          expect(resource_type.resource_type_general.value).to eq "Other"
        end
      end

      context "with multiple titles" do
        let(:resource_titles) do
          [
            PDCMetadata::Title.new(title: "example subtitle", title_type: "Subtitle"),
            PDCMetadata::Title.new(title: "example alternative title", title_type: "AlternativeTitle"),
            PDCMetadata::Title.new(title: "example translated title", title_type: "TranslatedTitle")
          ]
        end
        let(:work_resource) do
          json = {
            "doi": doi,
            "identifier_type": "DOI",
            "titles": resource_titles,
            "description": "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
            "creators": [
              { "value": "Kotin, Joshua", "name_type": "Personal", "given_name": "Joshua", "family_name": "Kotin", "affiliations": [], "sequence": "1" }
            ],
            "resource_type": "Dataset",
            "publisher": "Princeton University",
            "publication_year": "2020"
          }.to_json
          PDCMetadata::Resource.new_from_json(json)
        end

        it "has titles" do
          titles = mapping.titles

          expect(titles).to be_an(Array)
          expect(titles.length).to eq(3)

          subtitle_title = titles.first
          expect(subtitle_title).to be_a(::Datacite::Mapping::Title)
          expect(subtitle_title.value).to eq("example subtitle")
          expect(subtitle_title.type).to be_a(Datacite::Mapping::TitleType)
          expect(subtitle_title.type.value).to eq("Subtitle")

          alt_title = titles[1]
          expect(alt_title).to be_a(::Datacite::Mapping::Title)
          expect(alt_title.value).to eq("example alternative title")
          expect(alt_title.type).to be_a(Datacite::Mapping::TitleType)
          expect(alt_title.type.value).to eq("AlternativeTitle")

          translated_title = titles.last
          expect(translated_title).to be_a(::Datacite::Mapping::Title)
          expect(translated_title.value).to eq("example translated title")
          expect(translated_title.type).to be_a(Datacite::Mapping::TitleType)
          expect(translated_title.type.value).to eq("TranslatedTitle")
        end
      end
    end
  end
end
