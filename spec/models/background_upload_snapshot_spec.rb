# frozen_string_literal: true
require "rails_helper"

RSpec.describe BackgroundUploadSnapshot, type: :model do
  subject(:background_upload_snapshot) { described_class.create(files: [], url: "example.com", work: work, id: 123) }
  let(:work) { FactoryBot.create(:approved_work) }
  let(:uploaded_file1) { fixture_file_upload("us_covid_2019.csv", "text/csv") }
  let(:uploaded_file2) { fixture_file_upload("us_covid_2020.csv", "text/csv") }

  describe "#count" do
    it "only counts the bacground uploads" do
      background_upload_snapshot
      UploadSnapshot.create(files: [], url: "example", work: work)
      expect(BackgroundUploadSnapshot.count).to eq(1)
    end
  end

  describe "#store_files" do
    it "lists filenames associated with the snapshot" do
      background_upload_snapshot.store_files([uploaded_file1, uploaded_file2])
      expect(background_upload_snapshot.files).to eq([{ "filename" => "#{work.prefix}us_covid_2019.csv", "upload_status" => "started", "user_id" => nil, "snapshot_id" => 123 },
                                                      { "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "started", "user_id" => nil, "snapshot_id" => 123 }])
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
      background_upload_snapshot.store_files([uploaded_file1, uploaded_file2])
      expect(work.work_activity.count).to eq(0)
      background_upload_snapshot.mark_complete(uploaded_file2.original_filename, "checksumabc123")
      expect(work.work_activity.count).to eq(0)
      expect(background_upload_snapshot.files).to eq([{ "filename" => "#{work.prefix}us_covid_2019.csv", "upload_status" => "started", "user_id" => nil, "snapshot_id" => 123 },
                                                      { "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "complete", "user_id" => nil, "checksum" => "checksumabc123",
                                                        "snapshot_id" => 123 }])
      expect(background_upload_snapshot.upload_complete?).to be_falsey
      expect(background_upload_snapshot.existing_files).to eq([{ "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "complete", "user_id" => nil, "checksum" => "checksumabc123",
                                                                 "snapshot_id" => 123 }])
      background_upload_snapshot.mark_complete(uploaded_file1.original_filename, "checksumdef456")
      expect(background_upload_snapshot.upload_complete?).to be_truthy
      expect(background_upload_snapshot.existing_files).to eq([{ "filename" => "#{work.prefix}us_covid_2019.csv", "upload_status" => "complete",
                                                                 "user_id" => nil, "checksum" => "checksumdef456", "snapshot_id" => 123 },
                                                               { "filename" => "#{work.prefix}us_covid_2020.csv", "upload_status" => "complete", "user_id" => nil, "checksum" => "checksumabc123",
                                                                 "snapshot_id" => 123 }])
      expect(work.work_activity.count).to eq(1)
      expect(work.work_activity.first.message).to eq("[{\"action\":\"added\",\"filename\":\"#{work.prefix}us_covid_2019.csv\"}"\
      ",{\"action\":\"added\",\"filename\":\"#{work.prefix}us_covid_2020.csv\"}]")
      expect(work.work_activity.first.created_by_user_id).to eq(nil)
    end
  end
end
