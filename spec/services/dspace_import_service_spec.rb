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
      expect(imported.dublin_core.title).to eq("The U.S. National Pandemic Emotional Impact Report")
    end
  end
end
