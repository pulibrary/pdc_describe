# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDspaceConnector, type: :model do
  include ActiveJob::TestHelper

  subject(:dspace_data) { described_class.new(work) }
  let(:work) { FactoryBot.create :draft_work }

  describe "#bitstreams" do
    it "finds no bitstreams" do
      expect(dspace_data.bitstreams).to be_empty
    end
  end

  describe "#download_bitstreams" do
    it "finds no bitstreams" do
      expect(dspace_data.download_bitstreams(dspace_data.list_bitsteams)).to be_empty
    end
  end

  describe "#metdata" do
    it "finds no metdata" do
      expect(dspace_data.metadata).to eq({})
    end
  end

  describe "#doi" do
    it "finds no doi" do
      expect(dspace_data.doi).to be_empty
    end
  end

  context "the work is a dspace migrated object" do
    let(:work) { FactoryBot.create :shakespeare_and_company_work }
    let(:handle_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_handle.json")) }
    let(:bitsreams_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_bitstreams_response.json")) }
    let(:metadata_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_metadata_response.json")) }
    let(:process_status) { instance_double Process::Status, "success?": true }
    before do
      stub_request(:get, "https://dataspace.example.com/rest/handle/88435/dsp01zc77st047")
        .to_return(status: 200, body: handle_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/bitstreams?offset=0&limit=20")
        .to_return(status: 200, body: bitsreams_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/metadata")
        .to_return(status: 200, body: metadata_body, headers: {})
      allow(Open3).to receive(:capture2e).and_return(["", process_status])
      FileUtils.mkdir_p("/tmp/dspace_download/#{work.id}")
      FileUtils.cp(Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_README.txt"),
        "/tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_README.txt")
      FileUtils.cp(Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_datapackage.json"),
        "/tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json")
      FileUtils.cp(Rails.root.join("spec", "fixtures", "files", "bitstreams", "license.txt"),
        "/tmp/dspace_download/#{work.id}/license.txt")
    end

    after do
      FileUtils.rm_r("/tmp/dspace_download/#{work.id}")
    end

    it "downloads the bitstreams" do
      allow(Honeybadger).to receive(:notify)
      expect(dspace_data.download_bitstreams(dspace_data.list_bitsteams).count).to eq(2)
      expect(Honeybadger).not_to have_received(:notify)
    end

    context "a bitstream missmatch" do
      # realy should be the readme, but we are intetionally returning the wrong data
      before do
        FileUtils.cp(Rails.root.join("spec", "fixtures", "files", "bitstreams", "license.txt"),
        "/tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_README.txt")
      end

      it "downloads the bitstreams" do
        allow(Honeybadger).to receive(:notify)
        expect(dspace_data.download_bitstreams(dspace_data.list_bitsteams).count).to eq(2)
        expect(Honeybadger).to have_received(:notify).with(/Mismatching checksum .* for work: #{work.id} doi: #{work.doi} ark: #{work.ark}/)
      end
    end
  end
end
