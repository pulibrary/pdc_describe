# frozen_string_literal: true
require "rails_helper"

RSpec.describe ApprovedFileMoveJob, type: :job do
  include ActiveJob::TestHelper
  let(:fake_completion) do
    fake_copy_object_result = instance_double(Aws::S3::Types::CopyObjectResult, etag: "\"abc123etagetag\"")
    fake_copy = instance_double(Aws::S3::Types::CopyObjectOutput, copy_object_result: fake_copy_object_result)
    fake_http_resp = instance_double(Seahorse::Client::Http::Response, status_code: 200, on_error: nil)
    fake_http_req = instance_double(Seahorse::Client::Http::Request)
    fake_request_context = instance_double(Seahorse::Client::RequestContext, http_response: fake_http_resp, http_request: fake_http_req)
    Seahorse::Client::Response.new(context: fake_request_context, data: fake_copy)
  end

  let(:user) { FactoryBot.create :user }

  let(:s3_file) { FactoryBot.build :s3_file, work: work, filename: "#{work.prefix}/test_key" }
  let(:approved_upload_snapshot) do
    snapshot = ApprovedUploadSnapshot.new(work: work)
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
      allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
      allow(fake_s3_service).to receive(:delete_s3_object).and_return(fake_completion)
      allow(fake_s3_service).to receive(:check_file).and_return(true)
      allow(fake_s3_service.client).to receive(:put_object).and_return(nil)
    end

    it "runs an aws copy and delete" do
      perform_enqueued_jobs { job }
      expect(fake_s3_service).to have_received(:copy_file).with(size: 200, source_key: "/example-bucket/#{s3_file.key}",
                                                                target_bucket: "example-bucket-post", target_key: s3_file.key)
      expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file.key, bucket: "example-bucket")
      expect(fake_s3_service).to have_received(:delete_s3_object).with(work.s3_object_key, bucket: "example-bucket")
      expect(approved_upload_snapshot.reload.files).to eq([{ "checksum" => "abc123etagetag", "filename" => s3_file.key, "upload_status" => "complete", "user_id" => user.id,
                                                             "snapshot_id" => approved_upload_snapshot.id }])
    end

    context "the copy fails" do
      before do
        fake_completion = instance_double(Seahorse::Client::Response, "successful?": false)
        allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
      end
      it "runs an aws copy, but no delete" do
        expect do
          perform_enqueued_jobs do
            job
          end
        end .to raise_error(/Error copying \/example-bucket\/10.34770\/ackh-7y71\/#{work.id}\/test_key to example-bucket-post\/10.34770\/ackh-7y71\/#{work.id}\/test_key/)
        expect(fake_s3_service).to have_received(:copy_file).with(size: 200, source_key: "/example-bucket/#{s3_file.key}",
                                                                  target_bucket: "example-bucket-post", target_key: s3_file.key)
        expect(fake_s3_service).not_to have_received(:delete_s3_object).with("example-bucket/#{s3_file.key}")
        expect(fake_s3_service).not_to have_received(:delete_s3_object).with(work.s3_object_key, bucket: "example-bucket")
      end
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
      allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
      allow(fake_s3_service).to receive(:delete_s3_object).and_return(fake_completion)
      allow(fake_s3_service).to receive(:check_file).and_return(true)
      allow(fake_s3_service.client).to receive(:put_object).and_return(nil)
    end

    it "creates the preservation files in the preservation bucket" do
      perform_enqueued_jobs { job }
      expect(fake_s3_service.client).to have_received(:put_object).with({ bucket: "example-bucket-preservation", content_length: 0, key: "#{work.doi}/#{work.id}/princeton_data_commons/" })
      expect(approved_upload_snapshot.reload.files).to eq([{ "checksum" => "abc123etagetag", "filename" => s3_file.key, "upload_status" => "complete", "user_id" => user.id,
                                                             "snapshot_id" => approved_upload_snapshot.id }])
    end
  end
end
