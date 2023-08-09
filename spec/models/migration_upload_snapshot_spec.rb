# frozen_string_literal: true
require "rails_helper"

RSpec.describe MigrationUploadSnapshot, type: :model do
  subject(:migration_upload_snapshot) { described_class.create(files: [], url: "example.com", work: work, id: 123) }
  let(:work) { FactoryBot.create(:approved_work) }
  let(:s3_file1) { FactoryBot.build :s3_file, filename: "fileone", checksum: "aaabbb111222" }
  let(:s3_file2) { FactoryBot.build :s3_file, filename: "filetwo", checksum: "dddeee111222" }

  describe "#count" do
    it "only counts the migrations" do
      migration_upload_snapshot
      UploadSnapshot.create(files: [], url: "example", work: work)
      expect(MigrationUploadSnapshot.count).to eq(1)
    end
  end

  describe "#store_files" do
    it "lists filenames associated with the snapshot" do
      migration_upload_snapshot.store_files([s3_file1, s3_file2])
      expect(migration_upload_snapshot.files).to eq([{ "filename" => "fileone", "checksum" => "aaabbb111222", "migrate_status" => "started" },
                                                     { "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "started" }])
      expect(migration_upload_snapshot.existing_files).to eq([])
      expect(migration_upload_snapshot.migration_complete?).to be_falsey
    end
  end

  describe "#mark_complete" do
    it "changes the status" do
      allow(Honeybadger).to receive(:notify)
      migration_upload_snapshot.store_files([s3_file1, s3_file2])
      expect(work.work_activity.count).to eq(0)
      migration_upload_snapshot.mark_complete(s3_file2)
      expect(work.work_activity.count).to eq(0)
      expect(migration_upload_snapshot.files).to eq([{ "filename" => "fileone", "checksum" => "aaabbb111222", "migrate_status" => "started" },
                                                     { "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "complete" }])
      expect(migration_upload_snapshot.migration_complete?).to be_falsey
      expect(migration_upload_snapshot.existing_files).to eq([{ "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "complete" }])
      migration_upload_snapshot.mark_complete(s3_file1)
      expect(migration_upload_snapshot.migration_complete?).to be_truthy
      expect(migration_upload_snapshot.existing_files).to eq([{ "filename" => "fileone", "checksum" => "aaabbb111222", "migrate_status" => "complete" },
                                                              { "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "complete" }])
      expect(work.work_activity.count).to eq(1)
      expect(work.work_activity.first.message).to eq("{\"migration_id\":123,\"message\":\"Migration from Dataspace is complete.\"}")
      expect(work.work_activity.first.created_by_user_id).to eq(nil)
      expect(Honeybadger).to have_received(:notify)
    end

    context "with a starting snapshot" do
      before do
        WorkActivity.add_work_activity(work.id, { migration_id: migration_upload_snapshot.id, message: "Started migration", file_count: 2, directory_count: 1 }.to_json, work.created_by_user_id,
activity_type: WorkActivity::MIGRATION_START)
      end
      it "changes the status" do
        allow(Honeybadger).to receive(:notify)
        migration_upload_snapshot.store_files([s3_file1, s3_file2])
        expect(work.work_activity.count).to eq(1)
        migration_upload_snapshot.mark_complete(s3_file2)
        expect(work.work_activity.count).to eq(1)
        expect(migration_upload_snapshot.files).to eq([{ "filename" => "fileone", "checksum" => "aaabbb111222", "migrate_status" => "started" },
                                                       { "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "complete" }])
        expect(migration_upload_snapshot.migration_complete?).to be_falsey
        expect(migration_upload_snapshot.existing_files).to eq([{ "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "complete" }])
        migration_upload_snapshot.mark_complete(s3_file1)
        expect(migration_upload_snapshot.migration_complete?).to be_truthy
        expect(migration_upload_snapshot.existing_files).to eq([{ "filename" => "fileone", "checksum" => "aaabbb111222", "migrate_status" => "complete" },
                                                                { "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "complete" }])
        expect(work.work_activity.count).to eq(2)
        expect(work.work_activity.first.message).to eq("{\"migration_id\":123,\"message\":\"2 files and 1 directory have migrated from Dataspace.\"}")
        expect(work.work_activity.first.created_by_user_id).to eq(work.created_by_user_id)
        expect(Honeybadger).not_to have_received(:notify)
      end
    end

    context "when a snapshot has an error" do
      before do
        migration_upload_snapshot.store_files([s3_file1, s3_file2])
        migration_upload_snapshot.mark_error(s3_file1, "an error")
      end
      it "can be completed" do
        expect(work.work_activity.count).to eq(0)
        migration_upload_snapshot.mark_complete(s3_file2)
        expect(work.work_activity.count).to eq(0)
        expect(migration_upload_snapshot.files).to eq([{ "filename" => "fileone", "checksum" => "aaabbb111222", "migrate_status" => "error", "migrate_error" => "an error" },
                                                       { "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "complete" }])
        expect(migration_upload_snapshot.migration_complete?).to be_falsey
        migration_upload_snapshot.mark_complete(s3_file1)
        expect(migration_upload_snapshot.migration_complete?).to be_truthy
        expect(migration_upload_snapshot.existing_files).to eq([{ "filename" => "fileone", "checksum" => "aaabbb111222", "migrate_status" => "complete" },
                                                                { "filename" => "filetwo", "checksum" => "dddeee111222", "migrate_status" => "complete" }])
        expect(work.work_activity.count).to eq(1)
        expect(work.work_activity.first.message).to eq("{\"migration_id\":123,\"message\":\"Migration from Dataspace is complete.\"}")
        expect(work.work_activity.first.created_by_user_id).to eq(nil)
      end
    end

    context "two version of the same file" do
      let(:s3_file3) { FactoryBot.build :s3_file, filename: "filetwo", checksum: "dddeee1112223" }

      it "marks the correct one complete based on the checksum" do
        migration_upload_snapshot.store_files([s3_file1, s3_file2, s3_file3])
        migration_upload_snapshot.mark_complete(s3_file1)
        migration_upload_snapshot.mark_complete(s3_file2)
        migration_upload_snapshot.mark_complete(s3_file3)
        expect(migration_upload_snapshot).to be_migration_complete
      end
    end
  end
end
