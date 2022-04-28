# frozen_string_literal: true
require "rails_helper"

describe DspaceImportService do
  subject(:dspace_import_service_library_pdfs) { described_class.new(url: url_library_pdf, collection: collection, user: user) }
  let(:ark_library_pdf) { "88435/dsp01h415pd635" }
  let(:url_library_pdf) do
    "https://dataspace.princeton.edu/oai/request?verb=GetRecord&identifier=oai:dataspace.princeton.edu:#{ark_library_pdf}&metadataPrefix=oai_dc"
  end
  let(:collection) { Collection.default }
  let(:user) { FactoryBot.create :user }
  let(:response_body_library_pdf) do
    file_fixture("oai/88435/dsp01h415pd635.xml").read
  end


  subject(:dspace_import_service_research_data) { described_class.new(url: url_research_data, collection: collection, user: user) }

  let(:ark_research_data) { "88435/dsp01d791sj97j" }
  let(:url_research_data) do
    "https://dataspace.princeton.edu/oai/request?verb=GetRecord&identifier=oai:dataspace.princeton.edu:#{ark_research_data}&metadataPrefix=oai_dc"
  end
  let(:collection) { Collection.default }
  let(:user) { FactoryBot.create :user }
  let(:response_body_research_data) do
    file_fixture("oai/research_data/88435/dsp01d791sj97j.xml").read
  end

  describe "#import!" do
    let(:imported_library_pdf) { dspace_import_service_library_pdfs.import! }
    before do
      stub_request(:get, url_library_pdf).with(
        headers: {
          "Content-Type" => "application/xml"
        }
      ).to_return(status: 200, body: response_body_library_pdf, headers: {
                    "Content-Type" => "application/xml"
                  })
    end

    it "creates a new Library PDF work from imported Dublin Core XML metadata" do
      expect(imported_library_pdf.title).to eq("The U.S. National Pandemic Emotional Impact Report")
      expect(imported_library_pdf.dublin_core.title).to be_an(Array)
      expect(imported_library_pdf.dublin_core.title).to include("The U.S. National Pandemic Emotional Impact Report")
      expect(imported_library_pdf.dublin_core.title).to include("Findings of a nationwide survey assessing the effects of the COVID-19 pandemic on the emotional wellbeing of the U.S. adult population.")

      expect(imported_library_pdf.dublin_core.creator).to be_an(Array)
      expect(imported_library_pdf.dublin_core.creator).to include("Palsson, Olafur")
      expect(imported_library_pdf.dublin_core.creator).to include("Ballou, Sarah")
      expect(imported_library_pdf.dublin_core.creator).to include("Gray, Sarah")

      expect(imported_library_pdf.dublin_core.subject).to be_an(Array)
      expect(imported_library_pdf.dublin_core.subject).to include("Pandemics and COVID-19")
      expect(imported_library_pdf.dublin_core.subject).to include("Survey research.")

      expect(imported_library_pdf.dublin_core.date).to be_an(Array)
      expect(imported_library_pdf.dublin_core.date).to include("2021-04-02T12:53:32Z")

      expect(imported_library_pdf.dublin_core.identifier).to be_an(Array)
      expect(imported_library_pdf.dublin_core.identifier).to include("http://arks.princeton.edu/ark:/88435/dsp01h415pd635")

      expect(imported_library_pdf.dublin_core.language).to be_an(Array)
      # expect(imported_library_pdf.dublin_core.language).to include("The U.S. National Pandemic Emotional Impact Report")

      expect(imported_library_pdf.dublin_core.relation).to be_an(Array)
      # expect(imported_library_pdf.dublin_core.relation).to include("The U.S. National Pandemic Emotional Impact Report")

      expect(imported_library_pdf.dublin_core.publisher).to be_an(Array)
      # expect(imported_library_pdf.dublin_core.publisher).to include("The U.S. National Pandemic Emotional Impact Report")
    end

    context "create research data" do
    end

    let(:imported_research_data) { dspace_import_service_research_data.import! }
    before do
      stub_request(:get, url_research_data).with(
        headers: {
          "Content-Type" => "application/xml"
        }
      ).to_return(status: 200, body: response_body_research_data, headers: {
                    "Content-Type" => "application/xml"
                  })
    end

    it "creates a new Research Data work from imported Dublin Core XML metadata" do
      expect(imported_research_data.title).to eq("Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It")
      expect(imported_research_data.dublin_core.title).to be_an(Array)
      expect(imported_research_data.dublin_core.title).to include("Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It")

      expect(imported_research_data.dublin_core.creator).to be_an(Array)
      expect(imported_research_data.dublin_core.creator).to include("Abrams, Samantha")
      expect(imported_research_data.dublin_core.creator).to include("Antracoli, Alexis")
      expect(imported_research_data.dublin_core.creator).to include("Appel, Rachel")
      expect(imported_research_data.dublin_core.creator).to include("Caust-Ellenbogen, Celia")
      expect(imported_research_data.dublin_core.creator).to include("Dennison, Sarah")
      expect(imported_research_data.dublin_core.creator).to include("Duncan, Sumitra")
      expect(imported_research_data.dublin_core.creator).to include("Ramsay, Stefanie")

      expect(imported_research_data.dublin_core.date).to be_an(Array)
      expect(imported_research_data.dublin_core.date).to include("2019-04-29T14:54:20Z")

      expect(imported_research_data.dublin_core.identifier).to be_an(Array)
      expect(imported_research_data.dublin_core.identifier).to include("http://arks.princeton.edu/ark:/88435/dsp01d791sj97j")

      expect(imported_research_data.dublin_core.relation).to be_an(Array)
      expect(imported_research_data.dublin_core.relation).to include("Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It, Fall/Winter 2019, Vol. 82, No. 2.")

      expect(imported_research_data.dublin_core.language).to be_an(Array)

      expect(imported_research_data.dublin_core.publisher).to be_an(Array)
    end
  end
end
