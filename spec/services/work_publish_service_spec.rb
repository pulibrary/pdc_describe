# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkPublishService do
  include ActiveJob::TestHelper

  let(:work_publish_service) { described_class.new(work:, current_user: user) }
  let(:s3_query_service) { S3QueryService.new(work) }

  # DOI for Shakespeare and Company Project Dataset: Lending Library Members, Books, Events
  # https://dataspace.princeton.edu/handle/88435/dsp01zc77st047
  let(:doi) { "10.34770/pe9w-x904" }

  let(:user) { FactoryBot.create(:user) }
  let(:work) { FactoryBot.create(:draft_work, doi:) }
  let(:fake_aws_client) { double(Aws::S3::Client) }
  let(:fake_multi) { instance_double(Aws::S3::Types::CreateMultipartUploadOutput, key: "abc", upload_id: "upload id", bucket: "bucket") }
  let(:fake_parts) { instance_double(Aws::S3::Types::CopyPartResult, etag: "etag123abc", checksum_sha256: "sha256abc123") }
  let(:fake_upload) { instance_double(Aws::S3::Types::UploadPartCopyOutput, copy_part_result: fake_parts) }
  let(:fake_s3_resp) { double(Aws::S3::Types::ListObjectsV2Output, is_truncated: false) }
  let(:preservation_service) { instance_double(WorkPreservationService) }

  let(:s3_bucket_key) { "10.34770/pe9w-x904/#{work.id}/" }
  let(:s3_key1) { "#{s3_bucket_key}SCoData_combined_v1_2020-07_README.txt" }
  let(:s3_key2) { "#{s3_bucket_key}SCoData_combined_v1_2020-07_datapackage.json" }
  let(:s3_key3) { "#{s3_bucket_key}a_directory/" }
  let(:s3_last_modified1) { Time.parse("2022-04-21T18:29:40.000Z") }
  let(:s3_last_modified2) { Time.parse("2022-04-21T18:30:07.000Z") }
  let(:s3_last_modified3) { Time.parse("2022-05-21T18:31:07.000Z") }
  let(:s3_size1) { 5_368_709_122 }
  let(:s3_size2) { 5_368_709_128 }
  let(:s3_size3) { 0 }
  let(:s3_etag1) { "008eec11c39e7038409739c0160a793a" }

  let(:s3_hash) do
    {
      is_truncated: false,
      contents: [
        {
          etag: "\"#{s3_etag1}\"",
          key: s3_key1,
          last_modified: s3_last_modified1,
          size: s3_size1,
          storage_class: "STANDARD"
        },
        {
          etag: "\"7bd3d4339c034ebc663b990657714688\"",
          key: s3_key2,
          last_modified: s3_last_modified2,
          size: s3_size2,
          storage_class: "STANDARD"
        },
        {
          etag: "\"7bd3d4339c034ebc663b99065771111\"",
          key: s3_key3, ## this is a directory
          last_modified: s3_last_modified3,
          size: s3_size3,
          storage_class: "STANDARD"
        }
      ],
      key_count: 3
    }
  end

  let(:empty_s3_hash) do
    {
      is_truncated: false,
      contents: []
    }
  end

  before do
    Group.create_defaults
    user

    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    work

    allow(S3QueryService).to receive(:new).and_return(s3_query_service)
    allow(s3_query_service).to receive(:client).and_return(fake_aws_client)
    fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
    fake_s3_resp.stub(:to_h).and_return(s3_hash)
    fake_copy_object_result = instance_double(Aws::S3::Types::CopyObjectResult, etag: "\"abc123etagetag\"")
    fake_copy = instance_double(Aws::S3::Types::CopyObjectOutput, copy_object_result: fake_copy_object_result)
    fake_http_resp = instance_double(Seahorse::Client::Http::Response, status_code: 200, on_error: nil)
    fake_http_req = instance_double(Seahorse::Client::Http::Request)
    fake_request_context = instance_double(Seahorse::Client::RequestContext, http_response: fake_http_resp, http_request: fake_http_req)
    fake_completion = Seahorse::Client::Response.new(context: fake_request_context, data: fake_copy)
    fake_delete = instance_double(Aws::S3::Types::DeleteObjectOutput, "to_h": {})

    allow(s3_query_service.client).to receive(:create_multipart_upload).and_return(fake_multi)
    allow(s3_query_service.client).to receive(:upload_part_copy).and_return(fake_upload)
    allow(s3_query_service.client).to receive(:delete_object).and_return(fake_delete)
    allow(s3_query_service.client).to receive(:complete_multipart_upload).and_return(fake_completion)
    allow(s3_query_service.client).to receive(:put_object).and_return(nil)
    allow(s3_query_service.client).to receive(:copy_object).and_return(fake_completion)

    allow(s3_query_service.client).to receive(:head_object).with({ bucket: "example-bucket", key: work.s3_object_key }).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))

    allow(WorkPreservationService).to receive(:new).and_return(preservation_service)
    allow(preservation_service).to receive(:preserve!)
  end

  describe "#publish" do
    it "moves the files calling create_multipart_upload, head_object, and delete_object twice, once for each file, and called the preservation service" do
      # Allow the all files to check out
      allow(fake_s3_resp).to receive(:key_count).and_return(1)
      expect do
        expect(work_publish_service.publish).to be_truthy
      end.to change { work.upload_snapshots.count }.by 1
      fake_s3_resp.stub(:to_h).and_return(s3_hash, s3_hash, empty_s3_hash)
      snapshot = work.upload_snapshots.first
      expect(snapshot.files).to eq([
                                     { "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_README.txt", "snapshot_id" => snapshot.id, "upload_status" => "started",
                                       "user_id" => user.id, "checksum" => "008eec11c39e7038409739c0160a793a" },
                                     { "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json", "snapshot_id" => snapshot.id, "upload_status" => "started",
                                       "user_id" => user.id, "checksum" => "7bd3d4339c034ebc663b990657714688" }
                                   ])
      assert_enqueued_jobs 2, only: ApprovedFileMoveJob
      assert_enqueued_jobs 1, only: EmptyDirectoryDeleteJob
      perform_enqueued_jobs
      expect(s3_query_service.client).to have_received(:create_multipart_upload)
        .with({ bucket: "example-bucket-post", key: s3_key1, checksum_algorithm: "SHA256" })
      expect(s3_query_service.client).to have_received(:create_multipart_upload)
        .with({ bucket: "example-bucket-post", key: s3_key2, checksum_algorithm: "SHA256" })
      expect(s3_query_service.client).to have_received(:upload_part_copy)
        .with({ bucket: "example-bucket-post", copy_source: "example-bucket/#{s3_key1}",
                copy_source_range: "bytes=0-5368709119", key: "abc", part_number: 1, upload_id: "upload id" })
      expect(s3_query_service.client).to have_received(:upload_part_copy)
        .with({ bucket: "example-bucket-post", copy_source: "example-bucket/#{s3_key1}",
                copy_source_range: "bytes=5368709120-5368709121", key: "abc", part_number: 2, upload_id: "upload id" })
      expect(s3_query_service.client).to have_received(:upload_part_copy)
        .with({ bucket: "example-bucket-post", copy_source: "example-bucket/#{s3_key2}",
                copy_source_range: "bytes=0-5368709119", key: "abc", part_number: 1, upload_id: "upload id" })
      expect(s3_query_service.client).to have_received(:upload_part_copy)
        .with({ bucket: "example-bucket-post", copy_source: "example-bucket/#{s3_key2}",
                copy_source_range: "bytes=5368709120-5368709127", key: "abc", part_number: 2, upload_id: "upload id" })
      expect(s3_query_service.client).to have_received(:complete_multipart_upload)
        .with({ bucket: "example-bucket-post", key: s3_key1, multipart_upload: { parts: [{ etag: "etag123abc", part_number: 1, checksum_sha256: "sha256abc123" },
                                                                                         { etag: "etag123abc", part_number: 2, checksum_sha256: "sha256abc123" }] }, upload_id: "upload id" })
      expect(s3_query_service.client).to have_received(:complete_multipart_upload)
        .with({ bucket: "example-bucket-post", key: s3_key2, multipart_upload: { parts: [{ etag: "etag123abc", part_number: 1, checksum_sha256: "sha256abc123" },
                                                                                         { etag: "etag123abc", part_number: 2, checksum_sha256: "sha256abc123" }] }, upload_id: "upload id" })

      expect(s3_query_service.client).to have_received(:list_objects_v2)
        .with({ bucket: "example-bucket-post", prefix: s3_key1, max_keys: 1 })
      expect(s3_query_service.client).to have_received(:list_objects_v2)
        .with({ bucket: "example-bucket-post", prefix: s3_key2, max_keys: 1 })
      expect(s3_query_service.client).to have_received(:delete_object)
        .with({ bucket: "example-bucket", key: s3_key1 })
      expect(s3_query_service.client).to have_received(:delete_object)
        .with({ bucket: "example-bucket", key: s3_key2 })
      expect(s3_query_service.client).to have_received(:delete_object)
        .with({ bucket: "example-bucket", key: s3_key3 })
      expect(preservation_service).to have_received(:preserve!)
      expect(snapshot.reload.files).to eq([
                                            { "checksum" => "abc123etagetag", "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_README.txt",
                                              "snapshot_id" => snapshot.id, "upload_status" => "complete", "user_id" => user.id },
                                            { "checksum" => "abc123etagetag", "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json",
                                              "snapshot_id" => snapshot.id, "upload_status" => "complete", "user_id" => user.id }
                                          ])
    end
    context "the copy fails for some reason" do
      it "Does not delete anything and returns the missing file" do
        # Allow the first file to check out and the second one to not
        allow(fake_s3_resp).to receive(:key_count).and_return(1, 0)

        expect(work_publish_service.publish).to be_truthy
        expect { perform_enqueued_jobs }.to raise_error(/File check was not valid/)
        expect(s3_query_service.client).to have_received(:create_multipart_upload)
          .with({ bucket: "example-bucket-post", key: s3_key1, checksum_algorithm: "SHA256" })
        expect(s3_query_service.client).to have_received(:create_multipart_upload)
          .with({ bucket: "example-bucket-post", key: s3_key2, checksum_algorithm: "SHA256" })
        expect(s3_query_service.client).to have_received(:list_objects_v2)
          .with({ bucket: "example-bucket-post", prefix: s3_key1, max_keys: 1 })
        expect(s3_query_service.client).to have_received(:list_objects_v2)
          .with({ bucket: "example-bucket-post", prefix: s3_key2, max_keys: 1 })
        expect(s3_query_service.client).to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: s3_key1 })
        expect(s3_query_service.client).not_to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: s3_key2 })
        expect(s3_query_service.client).not_to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: work.s3_object_key })
      end

      it "Does not delete anything and returns both missing files" do
        # Allow the all files to NOT check out
        allow(fake_s3_resp).to receive(:key_count).and_return(0)

        expect(work_publish_service.publish).to be_truthy
        assert_enqueued_jobs 2, only: ApprovedFileMoveJob
        assert_enqueued_jobs 1, only: EmptyDirectoryDeleteJob

        # both jobs create an exception
        expect { perform_enqueued_jobs }.to raise_error(/File check was not valid/)
        expect { perform_enqueued_jobs }.to raise_error(/File check was not valid/)

        expect(s3_query_service.client).to have_received(:create_multipart_upload)
          .with({ bucket: "example-bucket-post", key: s3_key1, checksum_algorithm: "SHA256" })
        expect(s3_query_service.client).to have_received(:create_multipart_upload)
          .with({ bucket: "example-bucket-post", key: s3_key2, checksum_algorithm: "SHA256" })
        expect(s3_query_service.client).to have_received(:list_objects_v2)
          .with({ bucket: "example-bucket-post", prefix: s3_key1, max_keys: 1 })
        expect(s3_query_service.client).to have_received(:list_objects_v2)
          .with({ bucket: "example-bucket-post", prefix: s3_key2, max_keys: 1 })
        expect(s3_query_service.client).not_to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: s3_key1 })
        expect(s3_query_service.client).not_to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: s3_key2 })
        expect(s3_query_service.client).not_to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: work.s3_object_key })
      end
    end

    context "when there are empty files" do
      let(:s3_hash) do
        {
          is_truncated: false,
          contents: [
            {
              etag: "\"#{s3_etag1}\"",
              key: s3_key1,
              last_modified: s3_last_modified1,
              size: s3_size1,
              storage_class: "STANDARD"
            },
            {
              etag: "\"7bd3d4339c034ebc663b990657714688\"",
              key: s3_key2,
              last_modified: s3_last_modified2,
              size: s3_size2,
              storage_class: "STANDARD"
            },
            {
              etag: "\"008eec11c39e7038409739c0160a793b\"",
              key: "#{s3_bucket_key}SCoData_combined_v1_2020-07_README.empty.txt", ## this is a directory
              last_modified: s3_last_modified3,
              size: 0,
              storage_class: "STANDARD"
            },
            {
              etag: "\"7bd3d4339c034ebc663b99065771111\"",
              key: s3_key3, ## this is a directory
              last_modified: s3_last_modified3,
              size: s3_size3,
              storage_class: "STANDARD"
            }
          ],
          key_count: 3
        }
      end

      it "moves the empty file and deletes the directory" do
        expect do
          expect(work_publish_service.publish).to be_truthy
        end.to change { work.upload_snapshots.count }.by 1
        assert_enqueued_jobs 3, only: ApprovedFileMoveJob
        assert_enqueued_jobs 1, only: EmptyDirectoryDeleteJob
        work.reload
        empty_key = "#{work.prefix}SCoData_combined_v1_2020-07_README.empty.txt"
        expect(work.work_activity.length).to eq(0)
        expect(work.uploads.length).to eq(4)
        expect(work.uploads[0].filename).to eq(empty_key)
        expect(work.uploads[1].filename).to eq(s3_key1)
        expect(work.uploads[2].filename).to eq(s3_key2)
        expect(work.uploads[3].filename).to eq(s3_key3)
      end
    end

    context "the move jobs takes a while" do
      it "enqueues the directory deletion for later" do
        allow(fake_s3_resp).to receive(:key_count).and_return(1, # s1 Key exists
                                                              1, # s2 key exists
                                                              3, # there are still files in the directory
                                                              1) # the directory is now empty
        expect do
          expect(work_publish_service.publish).to be_truthy
        end.to change { work.upload_snapshots.count }.by 1
        fake_s3_resp.stub(:to_h).and_return(s3_hash, s3_hash, empty_s3_hash)
        snapshot = work.upload_snapshots.first
        expect(snapshot.files).to eq([
                                       { "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_README.txt", "snapshot_id" => snapshot.id, "upload_status" => "started",
                                         "user_id" => user.id, "checksum" => "008eec11c39e7038409739c0160a793a" },
                                       { "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json", "snapshot_id" => snapshot.id, "upload_status" => "started",
                                         "user_id" => user.id, "checksum" => "7bd3d4339c034ebc663b990657714688" }
                                     ])
        assert_enqueued_jobs 2, only: ApprovedFileMoveJob
        assert_enqueued_jobs 1, only: EmptyDirectoryDeleteJob
        perform_enqueued_jobs
        expect(preservation_service).not_to have_received(:preserve!)

        # All files go through (key_count stubbed to 1 above)
        assert_enqueued_jobs 0, only: ApprovedFileMoveJob
        # the directory gets requeued (key_count stubbed 3 above)
        assert_enqueued_jobs 1, only: EmptyDirectoryDeleteJob
        perform_enqueued_jobs
        expect(preservation_service).to have_received(:preserve!)

        assert_enqueued_jobs 0, only: ApprovedFileMoveJob
        # the directory goes through (key_count stubbed 1 above)
        assert_enqueued_jobs 0, only: EmptyDirectoryDeleteJob
      end
    end
  end
end
