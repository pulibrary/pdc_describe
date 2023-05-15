# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDspaceMigrate, type: :model do
  include ActiveJob::TestHelper

  subject(:dspace_data) { described_class.new(work) }
  let(:work) { FactoryBot.create :draft_work }

  describe "#migrate" do
    it "does nothing" do
      expect(dspace_data.migrate).to be_nil
      expect(dspace_data.file_keys).to be_empty
      expect(dspace_data.directory_keys).to be_empty
      expect(work.resource.migrated).to be_falsey
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

    describe "#migrate" do
      let(:s3_file) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/test_key" }
      let(:s3_directory) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/test_directory_key", size: 0 }
      let(:fake_s3_service) { stub_s3(data: [s3_file, s3_directory], prefix: "bucket/123/abc/") }

      before do
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /SCoData_combined_v1_2020-07_README/))
                                                       .and_return("abc/123/SCoData_combined_v1_2020-07_README.txt")
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /SCoData_combined_v1_2020-07_datapackage/))
                                                       .and_return("abc/123/SCoData_combined_v1_2020-07_datapackage.json")
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /license/))
                                                       .and_return("abc/123/license.txt")
        fake_completion = instance_double(Seahorse::Client::Response, "successful?": true)
        allow(fake_s3_service).to receive(:copy_file).with(hash_including(target_key: /test_key/))
                                                     .and_return(fake_completion)
        allow(fake_s3_service).to receive(:copy_file).with(hash_including(target_key: /test_directory_key/))
                                                     .and_return(fake_completion)
      end
      it "migrates the content from dspace and aws" do
        expect(UploadSnapshot.all.count).to eq(0)
        FactoryBot.create(:upload_snapshot, work: work, files: [{ "checksum" => "abc123", "filename" => "bucket/123/abc/test_exist_key" }])
        dspace_data.migrate
        expect(dspace_data.file_keys).to eq(["abc/123/SCoData_combined_v1_2020-07_README.txt",
                                             "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                             "abc/123/license.txt",
                                             "10-34770/ackh-7y71/test_key"])
        expect(dspace_data.directory_keys).to eq(["10-34770/ackh-7y71/test_directory_key"])
        expect(dspace_data.migration_message).to eq("Migration for 4 files and 1 directory")

        expect(work.reload.resource.migrated).to be_truthy
        expect(enqueued_jobs.size).to eq(2)
        expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "008eec11c39e7038409739c0160a793a", "filename" => "bucket/123/abc/SCoData_combined_v1_2020-07_README.txt",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "7bd3d4339c034ebc663b990657714688", "filename" => "bucket/123/abc/SCoData_combined_v1_2020-07_datapackage.json",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "1e204dad3e9e1e2e6660eef9c33467e9", "filename" => "bucket/123/abc/license.txt", "migrate_status" => "complete" },
                                                          { "checksum" => "abc123", "filename" => "bucket/123/abc/test_key", "migrate_status" => "started" },
                                                          { "checksum" => "abc123", "filename" => "bucket/123/abc/test_exist_key" }])
        perform_enqueued_jobs
        expect(enqueued_jobs.size).to eq(0)
        expect(UploadSnapshot.all.count).to eq(2)
        expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "008eec11c39e7038409739c0160a793a", "filename" => "bucket/123/abc/SCoData_combined_v1_2020-07_README.txt",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "7bd3d4339c034ebc663b990657714688", "filename" => "bucket/123/abc/SCoData_combined_v1_2020-07_datapackage.json",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "1e204dad3e9e1e2e6660eef9c33467e9", "filename" => "bucket/123/abc/license.txt", "migrate_status" => "complete" },
                                                          { "checksum" => "abc123", "filename" => "bucket/123/abc/test_key", "migrate_status" => "complete" },
                                                          { "checksum" => "abc123", "filename" => "bucket/123/abc/test_exist_key" }])
        expect(MigrationUploadSnapshot.last.migration_complete?).to be_truthy
      end
    end
  end
end
