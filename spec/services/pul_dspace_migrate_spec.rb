# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDspaceMigrate, type: :model do
  include ActiveJob::TestHelper

  subject(:subject) { described_class.new(work) }
  let(:work) { FactoryBot.create :draft_work }

  describe "#migrate" do
    it "does nothing" do
      expect(subject.migrate).to be_nil
      expect(subject.file_keys).to be_empty
      expect(subject.directory_keys).to be_empty
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
      let(:s3_file2) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/SCoData_combined_v1_2020-07_README.txt" }
      let(:s3_directory) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/test_directory_key", size: 0 }
      let(:fake_s3_service) { stub_s3(data: [s3_file, s3_file2, s3_directory], prefix: "abc/123/") }
      let(:fake_completion) { instance_double(Seahorse::Client::Response, "successful?": true) }

      before do
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /data_space_SCoData_combined_v1_2020-07_README/))
                                                       .and_return("abc/123/data_space_SCoData_combined_v1_2020-07_README.txt")
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /globus_SCoData_combined_v1_2020-07_README/))
                                                       .and_return("abc/123/globus_SCoData_combined_v1_2020-07_README.txt")
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /SCoData_combined_v1_2020-07_datapackage/))
                                                       .and_return("abc/123/SCoData_combined_v1_2020-07_datapackage.json")
        allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /license/))
                                                       .and_return("abc/123/license.txt")
        allow(fake_s3_service).to receive(:copy_file).with(hash_including(target_key: /test_key/))
                                                     .and_return(fake_completion)
        allow(fake_s3_service).to receive(:copy_file).with(hash_including(target_key: /test_directory_key/))
                                                     .and_return(fake_completion)
        allow(fake_s3_service).to receive(:copy_file).with(hash_including(target_key: /globus_SCoData_combined_v1_2020-07_README.txt/))
                                                     .and_return(fake_completion)
      end
      it "migrates the content from dspace and aws" do
        expect(UploadSnapshot.all.count).to eq(0)
        FactoryBot.create(:upload_snapshot, work: work, files: [{ "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
        subject.migrate
        expect(subject.file_keys).to eq(["abc/123/data_space_SCoData_combined_v1_2020-07_README.txt",
                                             "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                             "abc/123/license.txt",
                                             "abc/123/test_key",
                                             "abc/123/globus_SCoData_combined_v1_2020-07_README.txt"])
        expect(subject.directory_keys).to eq(["10-34770/ackh-7y71/test_directory_key"])
        expect(subject.migration_message).to eq("Migration for 5 files and 1 directory")

        expect(work.reload.resource.migrated).to be_truthy
        expect(enqueued_jobs.size).to eq(3)
        expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "008eec11c39e7038409739c0160a793a", "filename" => "abc/123/data_space_SCoData_combined_v1_2020-07_README.txt",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "7bd3d4339c034ebc663b990657714688", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "1e204dad3e9e1e2e6660eef9c33467e9", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "started" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/globus_SCoData_combined_v1_2020-07_README.txt", "migrate_status" => "started" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
        perform_enqueued_jobs
        expect(enqueued_jobs.size).to eq(0)
        expect(UploadSnapshot.all.count).to eq(2)
        expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "008eec11c39e7038409739c0160a793a", "filename" => "abc/123/data_space_SCoData_combined_v1_2020-07_README.txt",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "7bd3d4339c034ebc663b990657714688", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "1e204dad3e9e1e2e6660eef9c33467e9", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "complete" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/globus_SCoData_combined_v1_2020-07_README.txt", "migrate_status" => "complete" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
        expect(MigrationUploadSnapshot.last.migration_complete?).to be_truthy
      end

      it "does not attempt to migrate files from DataSpace if the ARK is on the manual migration list" do
        expect(work.resource.migrated).to be_falsey
        work.resource.ark = "ark:/88435/dsp01h415pd457"
        expect(work.skip_dataspace_migration?).to be_truthy
        subject.migrate
        expect(subject.migration_message).to match("DataSpace migration skipped for ark:/88435/dsp01h415pd457")
        expect(work.reload.resource.migrated).to be_truthy
        expect(enqueued_jobs.size).to eq(3) # but we still migrate the files from Globus
      end

      context "the checksums are the same" do
        let(:s3_file2) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/SCoData_combined_v1_2020-07_README.txt", checksum: "008eec11c39e7038409739c0160a793a" }

        before do
          allow(fake_s3_service).to receive(:copy_file).with(hash_including(target_key: /SCoData_combined_v1_2020-07_README.txt/))
                                                       .and_return(fake_completion)
        end

        it "migrates the content from dspace and aws skipping the same file" do
          expect(UploadSnapshot.all.count).to eq(0)
          FactoryBot.create(:upload_snapshot, work: work, files: [{ "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          subject.migrate
          expect(subject.file_keys).to eq(["abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                               "abc/123/license.txt",
                                               "abc/123/test_key",
                                               "abc/123/SCoData_combined_v1_2020-07_README.txt"])
          expect(subject.directory_keys).to eq(["10-34770/ackh-7y71/test_directory_key"])
          expect(subject.migration_message).to eq("Migration for 4 files and 1 directory")

          expect(work.reload.resource.migrated).to be_truthy
          expect(enqueued_jobs.size).to eq(3)
          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "7bd3d4339c034ebc663b990657714688", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "1e204dad3e9e1e2e6660eef9c33467e9", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "started" },
                                                            { "checksum" => "008eec11c39e7038409739c0160a793a", "filename" => "abc/123/SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "started" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          perform_enqueued_jobs
          expect(enqueued_jobs.size).to eq(0)
          expect(UploadSnapshot.all.count).to eq(2)
          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "7bd3d4339c034ebc663b990657714688", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "1e204dad3e9e1e2e6660eef9c33467e9", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "complete" },
                                                            { "checksum" => "008eec11c39e7038409739c0160a793a", "filename" => "abc/123/SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          expect(MigrationUploadSnapshot.last.migration_complete?).to be_truthy
        end
      end

      context "a dspace bitstream missmatch" do
        # realy should be the readme, but we are intetionally returning the wrong data
        let(:bitsream1_body) { "not the readme!!" }

        it "downloads the bitstreams" do
          allow(Honeybadger).to receive(:notify)
          expect { subject.migrate }.to raise_error("Error downloading file(s) SCoData_combined_v1_2020-07_README.txt")
          expect(Honeybadger).to have_received(:notify).with(/Mismatching checksum .* for work: #{work.id} doi: #{work.doi} ark: #{work.ark}/)
        end
      end
    end
  end
end
