# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDspaceAwsConnector, type: :model do
  include ActiveJob::TestHelper

  subject(:dspace_data) { described_class.new(work, "10.123456/acb-123") }
  let(:work) { FactoryBot.create :draft_work }

  describe "#aws_files" do
    it "finds no files" do
      expect(dspace_data.aws_files).to be_empty
    end
  end

  context "the work is a dspace migrated object" do
    let(:work) { FactoryBot.create :shakespeare_and_company_work }
    let(:handle_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_handle.json")) }
    let(:bitsreams_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_bitstreams_response.json")) }
    let(:metadata_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_metadata_response.json")) }
    let(:bitsream1_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_README.txt")) }
    let(:bitsream2_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_datapackage.json")) }
    let(:bitsream3_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "license.txt")) }
    before do
      stub_request(:get, "https://dataspace.example.com/rest/handle/88435/dsp01zc77st047")
        .to_return(status: 200, body: handle_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/bitstreams?offset=0&limit=20")
        .to_return(status: 200, body: bitsreams_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/metadata")
        .to_return(status: 200, body: metadata_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145784/retrieve")
        .to_return(status: 200, body: bitsream1_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145785/retrieve")
        .to_return(status: 200, body: bitsream2_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145762/retrieve")
        .to_return(status: 200, body: bitsream3_body, headers: {})
    end

    describe "#aws_files" do
      let(:s3_file) { FactoryBot.build :s3_file, filename: "test_key" }
      let(:fake_s3_service) { instance_double(S3QueryService, client_s3_files: [s3_file]) }

      before do
        allow(work).to receive(:s3_query_service).and_return(fake_s3_service)
      end
      it "finds files" do
        expect(dspace_data.aws_files).to eq([s3_file])
        expect(fake_s3_service).to have_received(:client_s3_files).with({ bucket_name: "example-bucket-dspace", prefix: "10-123456/acb-123",
                                                                          ignore_directories: false, reload: true })
      end
    end

    describe "#upload_bitstreams" do
      let(:file1) { FactoryBot.build :s3_file, filename: Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_README.txt").to_s }
      let(:file2) { FactoryBot.build :s3_file, filename: Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_datapackage.json").to_s }
      let(:file3) { FactoryBot.build :s3_file, filename: Rails.root.join("spec", "fixtures", "files", "bitstreams", "license.txt").to_s }
      let(:fake_s3_service) { stub_s3 }

      before do
        allow(fake_s3_service).to receive(:upload_file).and_return("key1", "key2", "key3")
      end

      it "uploads the bitstreams passed" do
        fake_s3_service
        results = dspace_data.upload_to_s3([file1, file2, file3])
        errors = results.pluck(:error)
        expect(errors).to eq [nil, nil, nil]
        keys = results.pluck(:key)
        expect(keys).to eq ["key1", "key2", "key3"]
        expect(fake_s3_service).to have_received(:upload_file).exactly(3).times
      end

      context " the upload failed" do
        before do
          allow(fake_s3_service).to receive(:upload_file).and_return("key1", false, "key2")
        end

        it "returns an error" do
          results = dspace_data.upload_to_s3([file1, file2, file3])
          errors = results.pluck(:error)
          expect(errors).to eq [nil, "An error uploading #{file2.filename}.  Please try again.", nil]
          keys = results.pluck(:key)
          expect(keys).to eq ["key1", nil, "key2"]
          expect(fake_s3_service).to have_received(:upload_file).exactly(3).times
        end
      end
    end
  end
end
