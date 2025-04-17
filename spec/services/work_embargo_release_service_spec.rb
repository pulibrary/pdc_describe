# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkEmbargoReleaseService do
  let(:work_embargo_service) { described_class.new(work:) }
  let(:user) { work.created_by_user }
  let(:work) { FactoryBot.create(:draft_work, doi: "10.34770/123-abc") }
  let(:key1) { "10.34770/123-abc/#{work.id}/embargo-file1.txt" }
  let(:key2) { "10.34770/123-abc/#{work.id}/embargo-file3.txt" }
  let(:file1) { FactoryBot.build :s3_file, filename: key1, work: }
  let(:file2) { FactoryBot.build :s3_file, filename: key2, work: }
  let(:fake_s3_service) { stub_s3(data: [file1, file2], prefix: "10.34770/123-abc/#{work.id}/") }
  let(:fake_s3_move) { instance_double S3MoveService }

  describe "#move" do
    it "calls move for each file and creates an upload snapshot and activity" do
      expect do
        fake_s3_service # make sure the fake is in place
        allow(S3MoveService).to receive(:new).and_return(fake_s3_move)
        allow(fake_s3_move).to receive(:move).and_return("etag1", "etag2")

        work_embargo_service.move
      end.to change { work.upload_snapshots.count }.by(1)
         .and change { work.work_activity.count }.by(1)
      snapshot = work.upload_snapshots.first
      expect(snapshot.files).to eq([
                                     { "filename" => key1, "snapshot_id" => snapshot.id, "upload_status" => "complete", "checksum" => "etag1" },
                                     { "filename" => key2, "snapshot_id" => snapshot.id, "upload_status" => "complete", "checksum" => "etag2" }
                                   ])
      activity = work.work_activity.last
      expect(S3MoveService).to have_received(:new).with(size: 10_759, source_bucket: "example-bucket-embargo", source_key: key1,
                                                        target_bucket: "example-bucket-post", target_key: key1, work_id: work.id)
      expect(S3MoveService).to have_received(:new).with(size: 10_759, source_bucket: "example-bucket-embargo", source_key: key2,
                                                        target_bucket: "example-bucket-post", target_key: key2, work_id: work.id)
      expect(activity.message).to eq("2 files were released from embargo to the post-curation bucket")
    end
  end
end
