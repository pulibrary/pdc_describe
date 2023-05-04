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

  describe "#dspace_bucket_name" do
    it "returns the base path" do
      expect(dspace_data.dspace_bucket_name).to eq("example-bucket-dspace")
    end
  end

  describe "#aws_files" do
    it "finds no files" do
      expect(dspace_data.aws_files).to be_empty
    end
  end

  describe "#migrate" do
    it "does nothing" do
      expect(dspace_data.migrate).to be_nil
      expect(dspace_data.file_keys).to be_empty
      expect(dspace_data.directory_keys).to be_empty
      expect(work.resource.migrated).to be_falsey
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
        allow(fake_s3_service).to receive(:upload_file).and_return(true, false, true)
      end

      it "returns an error" do
        errors = dspace_data.upload_to_s3([filename1, filename2, filename2])
        expect(errors).to eq [nil, "An error uploading #{filename2}.  Please try again.", nil]
        expect(fake_s3_service).to have_received(:upload_file).exactly(3).times
      end
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
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/bitstreams")
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

    describe "#metdata" do
      it "parses the metadata" do
        expect(dspace_data.metadata["dc.title"]).to eq(["TIGRESS simulation data"])
        expect(dspace_data.metadata["dc.identifier.uri"]).to eq(["http://arks.princeton.edu/ark:/88435/dsp01s7526g63n", "https://doi.org/10.34770/ackh-7y71", "https://app.globus.org/file-manager?origin_id=dc43f461-0ca7-4203-848c-33a9fc00a464&origin_path=%2Fackh-7y71%2F"])
      end
    end

    describe "#doi" do
      it "gets the doi from the metadata" do
        expect(dspace_data.doi).to eq("10.34770/ackh-7y71")
      end
    end

    describe "#aws_files" do
      let(:s3_file) { FactoryBot.build :s3_file, filename: "test_key" }
      let(:fake_s3_service) { instance_double(S3QueryService, client_s3_files: [s3_file]) }

      before do
        allow(work).to receive(:s3_query_service).and_return(fake_s3_service)
      end
      it "finds files" do
        expect(dspace_data.aws_files).to eq([s3_file])
        expect(fake_s3_service).to have_received(:client_s3_files).with({ bucket_name: "example-bucket-dspace", prefix: "10-34770/ackh-7y71",
                                                                          ignore_directories: false, reload: true })
      end
    end

    describe "#aws_copy" do
      let(:s3_file) { FactoryBot.build :s3_file, filename: "test_key" }
      let(:fake_s3_service) { instance_double(S3QueryService) }

      before do
        allow(work).to receive(:s3_query_service).and_return(fake_s3_service)
        allow(fake_s3_service).to receive(:copy_file)
      end

      it "copies files" do
        expect do
          expect(dspace_data.aws_copy([s3_file])).to eq([s3_file])
        end.to have_enqueued_job(DspaceFileCopyJob)
          .with("10.34770/ackh-7y71", "test_key", 10_759, work.id)
      end
    end

    describe "#migrate" do
      let(:s3_file) { FactoryBot.build :s3_file, filename: "test_key" }
      let(:s3_directory) { FactoryBot.build :s3_file, filename: "test_directory_key", size: 0 }
      let(:fake_s3_service) { instance_double(S3QueryService, client_s3_files: [s3_file, s3_directory]) }

      before do
        allow(work).to receive(:s3_query_service).and_return(fake_s3_service)
        allow(fake_s3_service).to receive(:copy_file)
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /SCoData_combined_v1_2020-07_README/))
                                                       .and_return("abc/123/SCoData_combined_v1_2020-07_README.txt")
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /SCoData_combined_v1_2020-07_datapackage/))
                                                       .and_return("abc/123/SCoData_combined_v1_2020-07_datapackage.json")
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /license/))
                                                       .and_return("abc/123/license.txt")
      end
      it "migrates the content from dspace and aws" do
        dspace_data.migrate
        expect(dspace_data.file_keys).to eq(["abc/123/SCoData_combined_v1_2020-07_README.txt",
                                             "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                             "abc/123/license.txt",
                                             "test_key"])
        expect(dspace_data.directory_keys).to eq(["test_directory_key"])
        expect(dspace_data.migration_message).to eq("Migration for 4 files and 1 directory")

        expect(work.reload.resource.migrated).to be_truthy
      end
    end
  end
end
