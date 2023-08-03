# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDspaceMigrate, type: :model do
  include ActiveJob::TestHelper

  subject(:subject) { described_class.new(work, user) }
  let(:work) { FactoryBot.create :draft_work }
  let(:user) { FactoryBot.create :user }

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
    let(:process_status) { instance_double Process::Status, "success?": true }
    before do
      stub_request(:get, "https://dataspace.example.com/rest/handle/88435/dsp01zc77st047")
        .to_return(status: 200, body: handle_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/handle/88435/dsp01h415pd457")
        .to_return(status: 200, body: handle_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/bitstreams")
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

        work_activity = WorkActivity.last
        expect(work_activity.message).to eq("{\"migration_id\":#{MigrationUploadSnapshot.last.id},\"message\":\"Migration for 5 files and 1 directory\",\"file_count\":5,\"directory_count\":1}")

        expect(enqueued_jobs.size).to eq(4)
        expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/data_space_SCoData_combined_v1_2020-07_README.txt",
                                                            "migrate_status" => "started" },
                                                          { "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                            "migrate_status" => "started" },
                                                          { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "started" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "started" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/globus_SCoData_combined_v1_2020-07_README.txt", "migrate_status" => "started" },
                                                          { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
        perform_enqueued_jobs
        expect(enqueued_jobs.size).to eq(0)
        expect(UploadSnapshot.all.count).to eq(2)
        expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/data_space_SCoData_combined_v1_2020-07_README.txt",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                            "migrate_status" => "complete" },
                                                          { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
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
        expect(subject.migration_snapshot).to be_instance_of MigrationUploadSnapshot
        expect(subject.migration_message).to match("DSpace migration skipped for ark:/88435/dsp01h415pd457")
        expect(work.reload.resource.migrated).to be_truthy
        expect(enqueued_jobs.size).to eq(3) # but we still migrate the files from Globus
      end

      context "the checksums are the same" do
        let(:s3_file2) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/SCoData_combined_v1_2020-07_README.txt", checksum: "AI7sEcOecDhAlznAFgp5Og==" }

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
          expect(enqueued_jobs.size).to eq(4)
          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "started" },
                                                            { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "started" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "started" },
                                                            { "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "started" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          perform_enqueued_jobs
          expect(enqueued_jobs.size).to eq(0)
          expect(UploadSnapshot.all.count).to eq(2)
          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "complete" },
                                                            { "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          expect(MigrationUploadSnapshot.last.migration_complete?).to be_truthy
          work_activity = WorkActivity.last
          expect(work_activity.message).to eq("{\"migration_id\":#{MigrationUploadSnapshot.last.id},\"message\":\"4 files and 1 directory have migrated from Dataspace.\"}")
          expect(work_activity.activity_type).to eq(WorkActivity::MIGRATION_COMPLETE)
        end
      end

      context "no files in aws" do
        let(:fake_s3_service) { stub_s3(prefix: "abc/123/") }

        before do
          allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /SCoData_combined_v1_2020-07_README/))
                                                         .and_return("abc/123/SCoData_combined_v1_2020-07_README.txt")
        end

        it "migrates the content from dspace only" do
          expect(UploadSnapshot.all.count).to eq(0)
          FactoryBot.create(:upload_snapshot, work: work, files: [{ "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          subject.migrate
          expect(subject.file_keys).to eq(["abc/123/SCoData_combined_v1_2020-07_README.txt",
                                           "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                           "abc/123/license.txt"])
          expect(subject.directory_keys).to eq([])
          expect(subject.migration_message).to eq("Migration for 3 files and 0 directories")

          expect(work.reload.resource.migrated).to be_truthy
          expect(enqueued_jobs.size).to eq(1)
          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "started" },
                                                            { "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "started" },
                                                            { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "started" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          perform_enqueued_jobs
          expect(enqueued_jobs.size).to eq(0)
          expect(UploadSnapshot.all.count).to eq(2)
          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          expect(MigrationUploadSnapshot.last.migration_complete?).to be_truthy
          start_work_activity = WorkActivity.first
          finish_work_activity = WorkActivity.last
          expect(start_work_activity.message)
            .to eq("{\"migration_id\":#{MigrationUploadSnapshot.last.id},\"message\":\"Migration for 3 files and 0 directories\",\"file_count\":3,\"directory_count\":0}")
          expect(start_work_activity.activity_type).to eq(WorkActivity::MIGRATION_START)
          expect(finish_work_activity.message).to eq("{\"migration_id\":#{MigrationUploadSnapshot.last.id},\"message\":\"3 files and 0 directories have migrated from Dataspace.\"}")
          expect(finish_work_activity.activity_type).to eq(WorkActivity::MIGRATION_COMPLETE)
        end
      end

      context "a dspace bitstream missmatch" do
        # realy should be the readme, but we are intetionally returning the wrong data
        before do
          FileUtils.cp(Rails.root.join("spec", "fixtures", "files", "bitstreams", "license.txt"),
          "/tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_README.txt")
        end

        it "downloads the bitstreams" do
          allow(Honeybadger).to receive(:notify)
          subject.migrate
          perform_enqueued_jobs
          expect(Honeybadger).to have_received(:notify).with(/Mismatching checksum .* for work: #{work.id} doi: #{work.doi} ark: #{work.ark}/)

          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/data_space_SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "error", "migrate_error" => "Checsum Missmatch" },
                                                            { "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/globus_SCoData_combined_v1_2020-07_README.txt", "migrate_status" => "complete" }])
          expect(MigrationUploadSnapshot.last.migration_complete?).to be_falsey
        end
      end

      context "an error occus moving uploading to aws" do
        before do
          allow(fake_s3_service).to receive(:upload_file).with(hash_including(filename: /data_space_SCoData_combined_v1_2020-07_README/))
                                                         .and_return(nil)
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

          work_activity = WorkActivity.last
          expect(work_activity.message).to eq("{\"migration_id\":#{MigrationUploadSnapshot.last.id},\"message\":\"Migration for 5 files and 1 directory\",\"file_count\":5,\"directory_count\":1}")

          expect(enqueued_jobs.size).to eq(4)
          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/data_space_SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "started" },
                                                            { "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "started" },
                                                            { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "started" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "started" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/globus_SCoData_combined_v1_2020-07_README.txt", "migrate_status" => "started" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          perform_enqueued_jobs
          expect(enqueued_jobs.size).to eq(0)
          expect(UploadSnapshot.all.count).to eq(2)
          expect(MigrationUploadSnapshot.last.files).to eq([{ "checksum" => "AI7sEcOecDhAlznAFgp5Og==", "filename" => "abc/123/data_space_SCoData_combined_v1_2020-07_README.txt",
                                                              "migrate_status" => "error",
                                                              "migrate_error" => "An error uploading /tmp/dspace_download/#{work.id}/SCoData_combined_v1_2020-07_README.txt.  Please try again." },
                                                            { "checksum" => "e9PUM5wDTrxmO5kGV3FGiA==", "filename" => "abc/123/SCoData_combined_v1_2020-07_datapackage.json",
                                                              "migrate_status" => "complete" },
                                                            { "checksum" => "HiBNrT6eHi5mYO75wzRn6Q==", "filename" => "abc/123/license.txt", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_key", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/globus_SCoData_combined_v1_2020-07_README.txt", "migrate_status" => "complete" },
                                                            { "checksum" => "abc123", "filename" => "abc/123/test_exist_key" }])
          expect(MigrationUploadSnapshot.last.migration_complete?).to be_falsey
          expect(MigrationUploadSnapshot.last.migration_complete_with_errors?).to be_truthy
        end
      end
    end
  end
end
