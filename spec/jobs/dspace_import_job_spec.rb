# frozen_string_literal: true
require "rails_helper"

describe DspaceImportJob, type: :job, mock_ezid_api: true do
  let(:ark) { "88435/dsp01h415pd635" }
  let(:url) do
    "https://dataspace.princeton.edu/oai/request?verb=GetRecord&identifier=oai:dataspace.princeton.edu:#{ark}&metadataPrefix=oai_dc"
  end
  let(:collection) { Collection.default }
  let(:user) { FactoryBot.create :user }
  let(:dspace_import_service) { instance_double(DspaceImportService) }

  before do
    allow(dspace_import_service).to receive(:import!)
    allow(DspaceImportService).to receive(:new).and_return(dspace_import_service)

    described_class.perform_now(url: url, user_id: user.id, collection_id: collection.id)
  end

  it ".perform" do
    # expect(DspaceImportService).to have_received(:new).with(url: url, user: user, collection: collection)
    expect(DspaceImportService).to have_received(:new)
    expect(dspace_import_service).to have_received(:import!)
  end
end
