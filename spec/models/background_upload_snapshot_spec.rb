# frozen_string_literal: true
require "rails_helper"

RSpec.describe BackgroundUploadSnapshot, type: :model do
  subject(:background_upload_snapshot) { described_class.create(files: [], url: "example.com", work:, id: 123) }
  let(:work) { FactoryBot.create(:approved_work) }
  let(:uploaded_file1) { fixture_file_upload("us_covid_2019.csv", "text/csv") }
  let(:uploaded_file2) { fixture_file_upload("us_covid_2020.csv", "text/csv") }
  let(:current_user) { work.created_by_user }

  describe "#count" do
    it "only counts the bacground uploads" do
      background_upload_snapshot
      UploadSnapshot.create(files: [], url: "example", work:)
      expect(BackgroundUploadSnapshot.count).to eq(1)
    end
  end

  describe "#store_files" do
    let(:current_user) { work.created_by_user }

    it "lists filenames associated with the snapshot" do
      background_upload_snapshot.store_files([uploaded_file1, uploaded_file2], current_user:)
      expect(background_upload_snapshot.files).to eq([{ "filename" => "#{work.prefix}us_covid_2019.csv", "upload_status" => "started", "snapshot_id" => 123, "user_id" => current_user.id },
                                                      { "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "started", "user_id" => current_user.id, "snapshot_id" => 123 }])
      expect(background_upload_snapshot.existing_files).to eq([])
      expect(background_upload_snapshot.upload_complete?).to be_falsey
    end

    context "with a user" do
      let(:user) { FactoryBot.create :user }
      it "lists filenames and user associated with the snapshot" do
        background_upload_snapshot.store_files([uploaded_file1, uploaded_file2], current_user: user)
        expect(background_upload_snapshot.files).to eq([{ "filename" => "#{work.prefix}us_covid_2019.csv", "upload_status" => "started", "user_id" => user.id, "snapshot_id" => 123 },
                                                        { "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "started", "user_id" => user.id, "snapshot_id" => 123 }])
        expect(background_upload_snapshot.existing_files).to eq([])
        expect(background_upload_snapshot.upload_complete?).to be_falsey
      end
    end
  end

  describe "#mark_complete" do
    it "changes the status" do
      allow(Honeybadger).to receive(:notify)
      background_upload_snapshot.store_files([uploaded_file1, uploaded_file2], current_user:)
      expect(work.work_activity.count).to eq(0)
      background_upload_snapshot.mark_complete(uploaded_file2.original_filename, "checksumabc123")
      expect(work.work_activity.count).to eq(0)
      expect(background_upload_snapshot.files).to eq([{ "filename" => "#{work.prefix}us_covid_2019.csv", "upload_status" => "started", "user_id" => current_user.id, "snapshot_id" => 123 },
                                                      { "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "complete", "user_id" => current_user.id, "checksum" => "checksumabc123",
                                                        "snapshot_id" => 123 }])
      expect(background_upload_snapshot.upload_complete?).to be_falsey
      # rubocop:disable Layout/LineLength
      expect(background_upload_snapshot.existing_files).to eq([{ "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "complete", "user_id" => current_user.id, "checksum" => "checksumabc123",
                                                                 "snapshot_id" => 123 }])
      background_upload_snapshot.mark_complete(uploaded_file1.original_filename, "checksumdef456")
      expect(background_upload_snapshot.upload_complete?).to be_truthy
      expect(background_upload_snapshot.existing_files).to eq([{ "filename" => "#{work.prefix}us_covid_2019.csv", "upload_status" => "complete",
                                                                 "user_id" => current_user.id, "checksum" => "checksumdef456", "snapshot_id" => 123 },
                                                               { "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "complete", "user_id" => current_user.id, "checksum" => "checksumabc123",
                                                                 "snapshot_id" => 123 }])
      # rubocop:enable Layout/LineLength
      expect(work.work_activity.count).to eq(1)
      expect(work.work_activity.first.message).to eq("[{\"action\":\"added\",\"filename\":\"#{work.prefix}us_covid_2019.csv\"}"\
      ",{\"action\":\"added\",\"filename\":\"#{work.prefix}us_covid_2020.csv\"}]")
      expect(work.work_activity.first.created_by_user_id).to eq(current_user.id)
    end
  end

  describe "#finalize_upload" do
    context "when no files are associated with the work" do
      it "raises an exception" do
        expect { background_upload_snapshot.finalize_upload }.to raise_error(ArgumentError, "Upload failed with empty files.")
      end
    end

    context "when the file is not associated with a user" do
      let(:uploaded_file1) { fixture_file_upload("us_covid_2019.csv", "text/csv") }
      let(:files) do
        [
          uploaded_file1
        ]
      end

      it "raises an error" do
        pattern = Regexp.escape("Failed to resolve the user ID from ")
        expect { background_upload_snapshot.store_files(files) }.to raise_error(ArgumentError, /#{pattern}/)
      end
    end
  end
end
