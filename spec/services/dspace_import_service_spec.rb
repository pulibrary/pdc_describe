# frozen_string_literal: true
require "rails_helper"

describe DspaceImportService do
  subject(:dspace_import_service) { described_class.new(url: url, collection: collection, user: user) }
  let(:ark) { "88435/dsp01h415pd635" }
  let(:url) do
    "https://dataspace.princeton.edu/oai/request?verb=GetRecord&identifier=oai:dataspace.princeton.edu:#{ark}&metadataPrefix=oai_dc"
  end
  let(:collection) { Collection.default }
  let(:user) { FactoryBot.create :user }
  let(:response_body) do
    file_fixture("oai/88435/dsp01h415pd635.xml").read
  end

  describe "#import!" do
    let(:imported) { dspace_import_service.import! }
    before do
      stub_request(:get, url).with(
        headers: {
          "Content-Type" => "application/xml"
        }
      ).to_return(status: 200, body: response_body, headers: {
                    "Content-Type" => "application/xml"
                  })
    end

    it "creates a new Work from imported Dublin Core XML metadata" do
      expect(imported.title).to eq("The U.S. National Pandemic Emotional Impact Report")
      expect(imported.dublin_core.title).to be_an(Array)
      expect(imported.dublin_core.title).to include("The U.S. National Pandemic Emotional Impact Report")
      expect(imported.dublin_core.title).to include("Findings of a nationwide survey assessing the effects of the COVID-19 pandemic on the emotional wellbeing of the U.S. adult population.")

      expect(imported.dublin_core.creator).to be_an(Array)
      expect(imported.dublin_core.creator).to include("Palsson, Olafur")
      expect(imported.dublin_core.creator).to include("Ballou, Sarah")
      expect(imported.dublin_core.creator).to include("Gray, Sarah")

      expect(imported.dublin_core.subject).to be_an(Array)
      expect(imported.dublin_core.subject).to include("Pandemics and COVID-19")
      expect(imported.dublin_core.subject).to include("Survey research.")

      expect(imported.dublin_core.date).to be_an(Array)
      expect(imported.dublin_core.date).to include("2021-04-02T12:53:32Z")

      expect(imported.dublin_core.identifier).to be_an(Array)
      expect(imported.dublin_core.identifier).to include("http://arks.princeton.edu/ark:/88435/dsp01h415pd635")

      expect(imported.dublin_core.language).to be_an(Array)
      # expect(imported.dublin_core.language).to include("The U.S. National Pandemic Emotional Impact Report")

      expect(imported.dublin_core.relation).to be_an(Array)
      # expect(imported.dublin_core.relation).to include("The U.S. National Pandemic Emotional Impact Report")

      expect(imported.dublin_core.publisher).to be_an(Array)
      # expect(imported.dublin_core.publisher).to include("The U.S. National Pandemic Emotional Impact Report")
    end
  end
end
