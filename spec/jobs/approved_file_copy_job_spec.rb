# frozen_string_literal: true
require "rails_helper"

RSpec.describe ApprovedFileMoveJob, type: :job do
  include ActiveJob::TestHelper
  let(:fake_completion) { build_fake_s3_completion }
  let(:fake_s3_move) { instance_double S3MoveService }

  let(:user) { FactoryBot.create :user }

  let(:s3_file) { FactoryBot.build :s3_file, work:, filename: "#{work.prefix}/test_key" }
  let(:approved_upload_snapshot) do
    snapshot = ApprovedUploadSnapshot.new(work:)
    snapshot.store_files([s3_file], current_user: user)
    snapshot.save!
    snapshot
  end

  describe "approval process" do
    subject(:job) do
      described_class.perform_later(work_id: work.id, source_bucket: "example-bucket", source_key: s3_file.key, target_bucket: "example-bucket-post",
                                    target_key: s3_file.key, size: 200, snapshot_id: approved_upload_snapshot.id)
    end
    let(:fake_s3_service) { stub_s3 prefix: "10.34770/ackh-7y71/#{work.id}" }
    let(:work) { FactoryBot.create :approved_work, doi: "10.34770/ackh-7y71" }

    before do
      allow(fake_s3_move).to receive(:move).and_return("abc123etagetag")
      allow(S3MoveService).to receive(:new).and_return(fake_s3_move)
      allow(fake_s3_service).to receive(:delete_s3_object).and_return(fake_completion)
      allow(fake_s3_service.s3client).to receive(:upload_file).and_return(true)
      allow(fake_s3_service.client).to receive(:put_object).and_return(nil)
    end

    it "runs an aws copy and delete and updates preservation information" do
      perform_enqueued_jobs { job }
      expect(S3MoveService).to have_received(:new).with(size: 200, work_id: work.id, source_bucket: "example-bucket", source_key: s3_file.key,
                                                        target_bucket: "example-bucket-post", target_key: s3_file.key)
      expect(fake_s3_move).to have_received(:move)
      expect(fake_s3_service).to have_received(:delete_s3_object).with(work.s3_object_key, bucket: "example-bucket")
      expect(approved_upload_snapshot.reload.files).to eq([{ "checksum" => "abc123etagetag", "filename" => s3_file.key, "upload_status" => "complete", "user_id" => user.id,
                                                             "snapshot_id" => approved_upload_snapshot.id }])
    end

    it "logs that files were moved to the post-curation bucket" do
      perform_enqueued_jobs { job }
      post_curation_activities = work.activities.select {|a| a.message.include?("moved to the post-curation bucket") }
      expect(post_curation_activities.count > 0).to be true
    end


    context "when the ApprovedUploadSnapshot cannot be found" do
      subject(:output) do
        described_class.perform_now(
          work_id: work.id,
          source_bucket: "example-bucket",
          source_key: s3_file.key,
          target_bucket: "example-bucket-post",
          target_key: s3_file.key,
          size: 200,
          snapshot_id: "invalid"
        )
      end
      let(:fake_s3_service) { stub_s3(bucket_name: "example-bucket-preservation") }
      let(:work) { FactoryBot.create :approved_work }

      it "raises an error" do
        expect(output).to be_an(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "embargo works" do
    subject(:job) do
      described_class.perform_later(work_id: work.id, source_bucket: "example-bucket", source_key: s3_file.key, target_bucket: "example-bucket-post",
                                    target_key: s3_file.key, size: 200, snapshot_id: approved_upload_snapshot.id)
    end
    let(:fake_s3_service) { stub_s3 prefix: "10.34770/ackh-7y71/#{work.id}" }
    let(:work) { FactoryBot.create :approved_work, doi: "10.34770/ackh-7y71", embargo_date: "2050-01-01" }

    before do
      allow(fake_s3_move).to receive(:move).and_return("abc123etagetag")
      allow(S3MoveService).to receive(:new).and_return(fake_s3_move)
      allow(fake_s3_service).to receive(:delete_s3_object).and_return(fake_completion)
      allow(fake_s3_service.s3client).to receive(:upload_file).and_return(true)
      allow(fake_s3_service.client).to receive(:put_object).and_return(nil)
    end

    it "logs that files were moved to the embargo bucket" do
      perform_enqueued_jobs { job }
      embargo_activities = work.activities.select {|a| a.message.include?("moved to the embargo bucket") }
      expect(embargo_activities.count > 0).to be true
    end
  end

  describe "preservation files after approval" do
    subject(:job) do
      described_class.perform_later(work_id: work.id, source_bucket: "example-bucket", source_key: s3_file.key, target_bucket: "example-bucket-post",
                                    target_key: s3_file.key, size: 200, snapshot_id: approved_upload_snapshot.id)
    end
    let(:fake_s3_service) { stub_s3(bucket_name: "example-bucket-preservation") }
    let(:work) { FactoryBot.create :approved_work }

    before do
      allow(fake_s3_move).to receive(:move).and_return("abc123etagetag")
      allow(S3MoveService).to receive(:new).and_return(fake_s3_move)
      allow(fake_s3_service).to receive(:delete_s3_object).and_return(fake_completion)
      allow(fake_s3_service.client).to receive(:put_object).and_return(nil)
      allow(fake_s3_service.s3client).to receive(:upload_file).and_return(true)
    end

    it "creates the preservation files in the preservation bucket" do
      perform_enqueued_jobs { job }
      expect(fake_s3_service.client).to have_received(:put_object).with({ bucket: "example-bucket-preservation", content_length: 0, key: "#{work.doi}/#{work.id}/princeton_data_commons/" })
      expect(approved_upload_snapshot.reload.files).to eq([{ "checksum" => "abc123etagetag", "filename" => s3_file.key, "upload_status" => "complete", "user_id" => user.id,
                                                             "snapshot_id" => approved_upload_snapshot.id }])
      expect(fake_s3_service.s3client).to have_received(:upload_file).with(target_key: "#{work.doi}/#{work.id}/princeton_data_commons/metadata.json", size: anything, io: anything)
      expect(fake_s3_service.s3client).to have_received(:upload_file).with(target_key: "#{work.doi}/#{work.id}/princeton_data_commons/datacite.xml", size: anything, io: anything)
      expect(fake_s3_service.s3client).to have_received(:upload_file).with(target_key: "#{work.doi}/#{work.id}/princeton_data_commons/provenance.json", size: anything, io: anything)
    end
  end
end
