# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkEmbargoService do
  let(:work_embargo_service) { described_class.new(work_id: work.id) }
  let(:user) { work.created_by_user }
  let(:work) { FactoryBot.create(:draft_work, doi: "10.34770/123-abc") }
  let(:file1) { FactoryBot.build :s3_file, filename: "10.34770/123-abc/#{work.id}/embargo-file1.txt", work: }
  let(:file2) { FactoryBot.build :s3_file, filename: "10.34770/123-abc/#{work.id}/embargo-file2.txt", work: }
  let(:fake_s3_service) { stub_s3(data: [file1, file2], prefix: "10.34770/123-abc/#{work.id}/") }
  let(:fake_s3_move) { instance_double S3MoveService }

  describe "#move" do
    it "calls move for each file and creates an upload snapshot and activity" do
      expect do
        fake_s3_service # make sure the fake is in place
        allow(S3MoveService).to receive(:new).and_return(fake_s3_move)
        allow(fake_s3_move).to receive(:move).and_return("etag1", "etag2")

        work_embargo_service.move(user:)
      end.to change { work.upload_snapshots.count }.by(1)
         .and change { work.work_activity.count }.by(1)
      snapshot = work.upload_snapshots.first
      expect(snapshot.files).to eq([
                                     { "filename" => "10.34770/123-abc/#{work.id}/embargo-file1.txt", "snapshot_id" => snapshot.id, "upload_status" => "complete",
                                       "user_id" => user.id, "checksum" => "etag1" },
                                     { "filename" => "10.34770/123-abc/#{work.id}/embargo-file2.txt", "snapshot_id" => snapshot.id, "upload_status" => "complete",
                                       "user_id" => user.id, "checksum" => "etag2" }
                                   ])
      activity = work.work_activity.last
      expect(activity.message).to eq("2 files were moved to the embargo bucket")
    end
  end
end
