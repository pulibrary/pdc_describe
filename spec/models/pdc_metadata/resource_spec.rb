# frozen_string_literal: true
require "rails_helper"

RSpec.describe PDCMetadata::Resource, type: :model do
  let(:creator1) do
    PDCMetadata::Creator.new_person("Elizabeth", "Miller", "1234-5678-9012-1234")
  end

  let(:creator2) do
    PDCMetadata::Creator.new_person("Jane", "Smith")
  end

  let(:ds) do
    ds = described_class.new(doi: "10.5072/example-full", title: "hello world")
    ds.description = "this is an example description"
    ds.creators = [creator1, creator2]
    ds.ark = "ark:/88435/dsp01hx11xj13h"
    ds.rights = PDCMetadata::Rights.find("CC BY")
    ds
  end

  describe ".resource_type_general_options" do
    it "accesses all options configured for the Open Access Repository (OAR)" do
      expect(described_class.resource_type_general_options).to be_a(Hash)
      expect(described_class.resource_type_general_options.values).to include("Collection")
      expect(described_class.resource_type_general_options.values).to include("Dataset")
      expect(described_class.resource_type_general_options.values).to include("DataPaper")
      expect(described_class.resource_type_general_options.values).to include("Event")
      expect(described_class.resource_type_general_options.values).to include("Image")
      expect(described_class.resource_type_general_options.values).to include("InteractiveResource")
      expect(described_class.resource_type_general_options.values).to include("Model")
      expect(described_class.resource_type_general_options.values).to include("PhysicalObject")
      expect(described_class.resource_type_general_options.values).to include("Service")
      expect(described_class.resource_type_general_options.values).to include("Software")
      expect(described_class.resource_type_general_options.values).to include("Sound")
      expect(described_class.resource_type_general_options.values).to include("Text")
      expect(described_class.resource_type_general_options.values).to include("Workflow")
      expect(described_class.resource_type_general_options.values).to include("Other")
    end

    it "filters for options configured for the Open Access Repository (OAR)" do
      expect(described_class.resource_type_general_options).to be_a(Hash)
      expect(described_class.resource_type_general_options.values).not_to include("Book")
      expect(described_class.resource_type_general_options.values).not_to include("BookChapter")
      expect(described_class.resource_type_general_options.values).not_to include("ConferencePaper")
      expect(described_class.resource_type_general_options.values).not_to include("ConferenceProceeding")
      expect(described_class.resource_type_general_options.values).not_to include("Dissertation")
      expect(described_class.resource_type_general_options.values).not_to include("Journal")
      expect(described_class.resource_type_general_options.values).not_to include("JournalArticle")
      expect(described_class.resource_type_general_options.values).not_to include("OutputManagementPlan")
      expect(described_class.resource_type_general_options.values).not_to include("PeerReview")
      expect(described_class.resource_type_general_options.values).not_to include("Preprint")
      expect(described_class.resource_type_general_options.values).not_to include("Report")
      expect(described_class.resource_type_general_options.values).not_to include("StudyRegistration")
    end
  end

  it "handles basic fields" do
    expect(ds.identifier).to eq "10.5072/example-full"
    expect(ds.main_title).to eq "hello world"
    expect(ds.resource_type).to eq "Dataset"
    expect(ds.creators.count).to be 2
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
    expect(work.metadata).to eq(work.to_json)
  end
end
