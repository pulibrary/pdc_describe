# frozen_string_literal: true
require "rails_helper"

RSpec.describe PDCMetadata::Resource, type: :model do
  let(:creator1) do
    PDCMetadata::Creator.new_person("Elizabeth", "Miller", "1234-5678-9012-1234")
  end

  let(:creator2) do
    PDCMetadata::Creator.new_person("Jane", "Smith")
  end

  let(:contributor1) { PDCMetadata::Creator.new_individual_contributor("Robert", "Smith", "", "PROJECT_LEADER", 1) }
  let(:contributor2) { PDCMetadata::Creator.new_individual_contributor("Simon", "Gallup", "", "OTHER", 2) }
  let(:doi) { "10.5072/example-full" }

  let(:ds) do
    ds = described_class.new(doi: doi, title: "hello world")
    ds.description = "this is an example description"
    ds.creators = [creator1, creator2]
    ds.ark = "ark:/88435/dsp01hx11xj13h"
    ds.rights = PDCMetadata::Rights.find("CC BY")
    ds.individual_contributors = [contributor1, contributor2]
    ds.publication_year = 2022
    ds
  end

  describe ".resource_type_general_values" do
    it "accesses all options configured for the Open Access Repository (OAR)" do
      expect(described_class.resource_type_general_values).to include("Collection")
      expect(described_class.resource_type_general_values).to include("Dataset")
      expect(described_class.resource_type_general_values).to include("DataPaper")
      expect(described_class.resource_type_general_values).to include("Event")
      expect(described_class.resource_type_general_values).to include("Image")
      expect(described_class.resource_type_general_values).to include("InteractiveResource")
      expect(described_class.resource_type_general_values).to include("Model")
      expect(described_class.resource_type_general_values).to include("PhysicalObject")
      expect(described_class.resource_type_general_values).to include("Service")
      expect(described_class.resource_type_general_values).to include("Software")
      expect(described_class.resource_type_general_values).to include("Sound")
      expect(described_class.resource_type_general_values).to include("Text")
      expect(described_class.resource_type_general_values).to include("Workflow")
      expect(described_class.resource_type_general_values).to include("Other")
    end

    it "filters for options configured for the Open Access Repository (OAR)" do
      expect(described_class.resource_type_general_values).not_to include("Book")
      expect(described_class.resource_type_general_values).not_to include("BookChapter")
      expect(described_class.resource_type_general_values).not_to include("ConferencePaper")
      expect(described_class.resource_type_general_values).not_to include("ConferenceProceeding")
      expect(described_class.resource_type_general_values).not_to include("Dissertation")
      expect(described_class.resource_type_general_values).not_to include("Journal")
      expect(described_class.resource_type_general_values).not_to include("JournalArticle")
      expect(described_class.resource_type_general_values).not_to include("OutputManagementPlan")
      expect(described_class.resource_type_general_values).not_to include("PeerReview")
      expect(described_class.resource_type_general_values).not_to include("Preprint")
      expect(described_class.resource_type_general_values).not_to include("Report")
      expect(described_class.resource_type_general_values).not_to include("StudyRegistration")
    end
  end

  it "handles basic fields" do
    expect(ds.identifier).to eq doi
    expect(ds.identifier_type).to eq("DOI")
    expect(ds.main_title).to eq "hello world"
    expect(ds.resource_type).to eq "Dataset"
    expect(ds.creators.count).to be 2
    expect(ds.individual_contributors.count).to be 2
    expect(ds.migrated).to be_falsey
  end

  describe "#identifier_type" do
    context "when the @doi instance variable is nil" do
      it "returns nil" do
        ds.doi = nil
        expect(ds.identifier_type).to be nil
      end
    end
  end

  it "supports more than one title" do
    ds.titles << PDCMetadata::Title.new(title: "hola mundo", title_type: "TranslatedTitle")
    expect(ds.titles.count).to be 2
  end

  it "serializes to xml" do
    # Eventually we might want to support a complete example like this
    # https://schema.datacite.org/meta/kernel-4.4/example/datacite-example-full-v4.xml
    raw_xml = file_fixture("datacite_basic.xml").read
    expect(ds.to_xml).to eq raw_xml
  end

  it "handles ORCID values" do
    expect(creator1.orcid).to eq "1234-5678-9012-1234"
    expect(creator1.orcid_url).to eq "https://orcid.org/1234-5678-9012-1234"

    no_orcid = PDCMetadata::Creator.new_person("Elizabeth", "Miller")
    expect(no_orcid.orcid).to be nil
  end

  it "creates the expected json" do
    work = FactoryBot.create(:shakespeare_and_company_work)
    expect(work.metadata).to eq(work.resource.as_json)
    expect(work.metadata).to eq(work.as_json["resource"])
  end

  it "allows for collection tags" do
    ds.collection_tags << "abc"
    ds.collection_tags << "123"
    expect(ds.collection_tags).to eq(["abc", "123"])
    expect(ds.to_json).to include("abc")
    expect(ds.to_json).to include("123")
  end

  it "allows for keywords" do
    ds.keywords << "red"
    ds.keywords << "green"
    expect(ds.keywords).to eq(["red", "green"])
    expect(ds.to_json).to include("red")
    expect(ds.to_json).to include("green")
  end

  it "allows for domains" do
    ds.domains << "Humanities"
    ds.domains << "Social Sciences"
    expect(ds.domains).to eq(["Humanities", "Social Sciences"])
    expect(ds.to_json).to include("Humanities")
    expect(ds.to_json).to include("Social Sciences")
  end

  describe "##new_from_jsonb" do
    let(:jsonb) do
      {
        "doi" => doi,
        "ark" => "88435/dsp01zc77st047",
        "titles" => [{ "title" => "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events", "title_type" => nil }],
        "description" => "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
        "contributors" => [
          { "value" => "Smith, Robert", "name_type" => "Personal", "given_name" => "Robert", "family_name" => "Smith", "affiliations" => [], "sequence" => 1, "identifier" => nil,
            "type" => "ProjectLeader" },
          { "value" => "Gallup, Simon", "name_type" => "Personal", "given_name" => "Simon", "family_name" => "Gallup", "affiliations" => [], "sequence" => 2, "identifier" => nil, "type" => "Other" }
        ],
        "organizational_contributors" => [
          { "affiliations" => [], "family_name" => nil, "given_name" => nil, "identifier" => { "scheme" => "ROR", "scheme_uri" => "https://ror.org", "value" => "https://ror.org/00hx57361" }, "name_type" => "Organizational", "sequence" => 0, "type" => nil, "value" => "Princeton University" }
        ],
        "creators" => [
          { "value" => "Kotin, Joshua", "name_type" => "Personal", "given_name" => "Joshua", "family_name" => "Kotin", "affiliations" => [], "sequence" => 1, "identifier" => nil }
        ],
        "resource_type" => "Dataset",
        "resource_type_general" => "Dataset",
        "publisher" => "Princeton University",
        "publication_year" => "2020",
        "collection_tags" => ["ABC", "123"],
        "keywords" => ["red", "yellow", "green"],
        "related_objects" => [],
        "rights" => { "identifier" => "CC BY", "name" => "Creative Commons Attribution 4.0 International", "uri" => "https://creativecommons.org/licenses/by/4.0/" },
        "version_number" => 1,
        "funders" => [{
          "ror" => nil,
          "funder_name" => nil,
          "award_number" => nil,
          "award_uri" => nil
        }],
        "domains" => ["Humanities"],
        "migrated" => true
      }
    end
    it "parses the json" do
      resource = described_class.new_from_jsonb(jsonb)
      expect(resource.doi).to eq(doi)
      expect(resource.collection_tags).to eq(["ABC", "123"])
      expect(resource.keywords).to eq(["red", "yellow", "green"])
      expect(resource.description).to eq("All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.")
      expect(resource.domains).to eq(["Humanities"])
      expect(resource.migrated).to be_truthy
      expect(JSON.parse(resource.to_json)).to eq(jsonb)
    end
  end
end
