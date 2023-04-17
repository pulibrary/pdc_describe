# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDspaceData, type: :model do
  subject(:dspace_data) { described_class.new(work) }
  let(:work) { FactoryBot.create :draft_work }

  describe "#id" do
    it "has no id by default" do
      expect(dspace_data.id).to be_nil
    end
  end

  describe "#bitstreams" do
    it "finds no bitstreams" do
      expect(dspace_data.bitstreams).to be_empty
    end
  end

  describe "#download_bitstreams" do
    it "finds no bitstreams" do
      expect(dspace_data.download_bitstreams).to be_empty
    end
  end

  describe "#upload_bitstreams" do
    let(:filename1) { Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_README.txt") }
    let(:filename2) { Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_datapackage.json") }
    let(:filename3) { Rails.root.join("spec", "fixtures", "files", "bitstreams", "license.txt") }
    let(:fake_s3_service) { stub_s3 }
    it "uploads the bitstreams passed" do
      fake_s3_service
      errors = dspace_data.upload_to_s3([filename1, filename2, filename2])
      expect(errors).to eq [nil, nil, nil]
      expect(fake_s3_service).to have_received(:upload_file).exactly(3).times
    end

    context " the upload failed" do
      before do
        allow(fake_s3_service).to receive(:upload_file).and_return([true, false, true])
      end

      it "returns an error" do
        errors = dspace_data.upload_to_s3([filename1, filename2, filename2])
        expect(errors).to eq [nil, nil, nil]
        expect(fake_s3_service).to have_received(:upload_file).exactly(3).times
      end
    end
  end

  context "the work is a dspace migrated object" do
    let(:work) { FactoryBot.create :shakespeare_and_company_work }
    let(:handle_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_handle.json")) }
    let(:bitsreams_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_bitstreams_response.json")) }
    let(:bitsream1_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_README.txt")) }
    let(:bitsream2_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_datapackage.json")) }
    let(:bitsream3_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "license.txt")) }
    before do
      stub_request(:get, "https://dataspace.example.com/rest/handle/88435/dsp01zc77st047")
        .to_return(status: 200, body: handle_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/bitstreams")
        .to_return(status: 200, body: bitsreams_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145784/retrieve")
        .to_return(status: 200, body: bitsream1_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145785/retrieve")
        .to_return(status: 200, body: bitsream2_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145762/retrieve")
        .to_return(status: 200, body: bitsream3_body, headers: {})
    end

    describe "#id" do
      it "looks up the dspace id" do
        expect(dspace_data.id).to eq(104_718)
      end
    end

    describe "#bitstreams" do
      it "finds the bitstreams" do
        expect(dspace_data.bitstreams.count).to eq(3)
        expect(dspace_data.bitstreams.map { |stream| stream["retrieveLink"] }).to eq(["/bitstreams/145784/retrieve", "/bitstreams/145785/retrieve", "/bitstreams/145762/retrieve"])
        expect(dspace_data.bitstreams.map { |stream| stream["checkSum"] }).to eq([{ "checkSumAlgorithm" => "MD5", "value" => "008eec11c39e7038409739c0160a793a" },
                                                                                  { "checkSumAlgorithm" => "MD5", "value" => "7bd3d4339c034ebc663b990657714688" },
                                                                                  { "checkSumAlgorithm" => "MD5", "value" => "1e204dad3e9e1e2e6660eef9c33467e9" }])
      end
    end

    describe "#download_bitstreams" do
      it "finds the bitstreams" do
        filenames = dspace_data.download_bitstreams
        expect(filenames.count).to eq(3)
        expect(filenames).to eq(["/tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_README.txt",
                                 "/tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json",
                                 "/tmp/dspace_download/#{work.id}/license.txt"])
        filenames.each { |filename| File.delete(filename) }
      end

      context " A checksum missmatch" do
        before do
          stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145762/retrieve")
            .to_return(status: 200, body: bitsream1_body, headers: {})
        end
        it "finds the valid bitstreams" do
          filenames = dspace_data.download_bitstreams
          expect(filenames.count).to eq(3)
          expect(filenames).to eq(["/tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_README.txt",
                                   "/tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json",
                                   nil])
          filenames.each { |filename| File.delete(filename) if filename.present? }
        end
      end

      context "An unknow Digest" do
        before do
          body = bitsreams_body.to_s.gsub("MD5", "unknown")
          stub_request(:get, "https://dataspace.example.com/rest/items/104718/bitstreams")
            .to_return(status: 200, body: body, headers: {})
        end

        it "finds no valid bitstreams" do
          filenames = dspace_data.download_bitstreams
          expect(filenames.count).to eq(3)
          expect(filenames).to eq([nil, nil, nil])
          filenames.each { |filename| File.delete(filename) if filename.present? }
        end
      end
    end
  end
end
