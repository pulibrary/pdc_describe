# frozen_string_literal: true
require "rails_helper"
require "rexml"

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
      jsonb_hash = {
        "doi" => doi,
        "identifier_type" => "DOI",
        "titles" => [{ "title" => "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }],
        "description" => "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
        "creators" => [
          { "value" => "Kotin, Joshua", "name_type" => "Personal", "given_name" => "Joshua", "family_name" => "Kotin", "affiliations" => [], "sequence" => "1" }
        ],
        "resource_type" => "Dataset",
        "publisher" => "Princeton University",
        "publication_year" => "2020"
      }
      PDCMetadata::Resource.new_from_jsonb(jsonb_hash)
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

      it "has a description" do
        expect(mapping.descriptions.first.value).to match(/All data is related to the Shakespeare and Company bookshop/)
      end

      context "contributor types" do
        it "maps contributor types" do
          expect(described_class.datacite_contributor_type("DataCollector")).to eq Datacite::Mapping::ContributorType::DATA_COLLECTOR
          expect(described_class.datacite_contributor_type("DataCurator")).to eq Datacite::Mapping::ContributorType::DATA_CURATOR
          expect(described_class.datacite_contributor_type("DataManager")).to eq Datacite::Mapping::ContributorType::DATA_MANAGER
          expect(described_class.datacite_contributor_type("Distributor")).to eq Datacite::Mapping::ContributorType::DISTRIBUTOR
          expect(described_class.datacite_contributor_type("Editor")).to eq Datacite::Mapping::ContributorType::EDITOR
          expect(described_class.datacite_contributor_type("HostingInstitution")).to eq Datacite::Mapping::ContributorType::HOSTING_INSTITUTION
          expect(described_class.datacite_contributor_type("Producer")).to eq Datacite::Mapping::ContributorType::PRODUCER
          expect(described_class.datacite_contributor_type("ProjectLeader")).to eq Datacite::Mapping::ContributorType::PROJECT_LEADER
          expect(described_class.datacite_contributor_type("ProjectManager")).to eq Datacite::Mapping::ContributorType::PROJECT_MANAGER
          expect(described_class.datacite_contributor_type("ProjectMember")).to eq Datacite::Mapping::ContributorType::PROJECT_MEMBER
          expect(described_class.datacite_contributor_type("RegistrationAgency")).to eq Datacite::Mapping::ContributorType::REGISTRATION_AGENCY
          expect(described_class.datacite_contributor_type("RegistrationAuthority")).to eq Datacite::Mapping::ContributorType::REGISTRATION_AUTHORITY
          expect(described_class.datacite_contributor_type("RelatedPerson")).to eq Datacite::Mapping::ContributorType::RELATED_PERSON
          expect(described_class.datacite_contributor_type("Researcher")).to eq Datacite::Mapping::ContributorType::RESEARCHER
          expect(described_class.datacite_contributor_type("ResearchGroup")).to eq Datacite::Mapping::ContributorType::RESEARCH_GROUP
          expect(described_class.datacite_contributor_type("RightsHolder")).to eq Datacite::Mapping::ContributorType::RIGHTS_HOLDER
          expect(described_class.datacite_contributor_type("Sponsor")).to eq Datacite::Mapping::ContributorType::SPONSOR
          expect(described_class.datacite_contributor_type("Supervisor")).to eq Datacite::Mapping::ContributorType::SUPERVISOR
          expect(described_class.datacite_contributor_type("WorkPackageLeader")).to eq Datacite::Mapping::ContributorType::WORK_PACKAGE_LEADER
          expect(described_class.datacite_contributor_type("Other")).to eq Datacite::Mapping::ContributorType::OTHER
        end
      end

      context "resource types" do
        it "maps dataset" do
          resource_type = described_class.datacite_resource_type("Dataset")
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
            { "title" => "example subtitle", "title_type" => "Subtitle" },
            { "title" => "example alternative title", "title_type" => "AlternativeTitle" },
            { "title" => "example translated title", "title_type" => "TranslatedTitle" }
          ]
        end
        let(:work_resource) do
          jsonb_hash = {
            "doi" => doi,
            "identifier_type" => "DOI",
            "titles" => resource_titles,
            "description" => "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
            "creators" => [
              { "value" => "Kotin, Joshua", "name_type" => "Personal", "given_name" => "Joshua", "family_name" => "Kotin", "affiliations" => [], "sequence" => "1" }
            ],
            "resource_type" => "Dataset",
            "publisher" => "Princeton University",
            "publication_year" => "2020"
          }
          PDCMetadata::Resource.new_from_jsonb(jsonb_hash)
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

  context "with an external related object" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:datacite) { work.resource.to_xml }
    let(:parsed_xml) { Datacite::Mapping::Resource.parse_xml(datacite) }

    it "references the related object in the datacite record" do
      stub_ark
      expect(parsed_xml.related_identifiers.count).to eq 3
      expect(parsed_xml.related_identifiers[0].identifier_type.value).to eq "ARK"
      expect(parsed_xml.related_identifiers[1].identifier_type.value).to eq "arXiv"
      expect(parsed_xml.related_identifiers[2].identifier_type.value).to eq "DOI"
    end
  end

  describe "resource JSON to Datacite XML" do
    fixtures_dir = "spec/fixtures/resource-to-datacite"
    Dir.glob("#{fixtures_dir}/*.resource.yaml").each do |resource_path|
      it "handles #{resource_path}" do
        resource = PDCMetadata::Resource.new_from_jsonb(YAML.load_file(resource_path))
        datacite_xml = resource.to_xml

        datacite_path = resource_path.gsub(".resource.yaml", ".datacite.xml")
        datacite_xml_expected = File.read(datacite_path)
        expect(datacite_xml).to be_equivalent_to(datacite_xml_expected)
      end
    end

    it "does not contain stray files" do
      Dir.glob("#{fixtures_dir}/*").each do |path|
        expect(path).to match(/\.resource\.yaml$|\.datacite\.xml$/)
      end
    end
  end

  context "schema validation" do
    let(:resource) { described_class.new_from_work(work) }
    context "valid XML record" do
      let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
      it "easily validates against our local datacite schema" do
        stub_ark
        expect(resource.valid?).to eq true
        expect(resource.errors.empty?).to eq true
      end
    end
  end
end
