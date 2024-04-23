# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3QueryService do
  include ActiveJob::TestHelper

  subject(:s3_query_service) { described_class.new(work) }
  let(:work) { FactoryBot.create :draft_work, doi: }
  let(:s3_bucket_key) { "10.34770/pe9w-x904/#{work.id}/" }
  let(:s3_key1) { "#{s3_bucket_key}SCoData_combined_v1_2020-07_README.txt" }
  let(:s3_key2) { "#{s3_bucket_key}SCoData_combined_v1_2020-07_datapackage.json" }
  let(:s3_last_modified1) { Time.parse("2022-04-21T18:29:40.000Z") }
  let(:s3_last_modified2) { Time.parse("2022-04-21T18:30:07.000Z") }
  let(:s3_size1) { 5_368_709_122 }
  let(:s3_size2) { 5_368_709_128 }
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
          key: "a_directory/",
          last_modified: s3_last_modified2,
          size: 0,
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

  # DOI for Shakespeare and Company Project Dataset: Lending Library Members, Books, Events
  # https://dataspace.princeton.edu/handle/88435/dsp01zc77st047
  let(:doi) { "10.34770/pe9w-x904" }

  let(:s3_attributes_response_body) do
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<GetObjectAttributesOutput>
  <ETag>#{s3_etag1}</ETag>
  <Checksum>
    <ChecksumCRC32>string</ChecksumCRC32>
    <ChecksumCRC32C>string</ChecksumCRC32C>
    <ChecksumSHA1>string</ChecksumSHA1>
    <ChecksumSHA256>string</ChecksumSHA256>
  </Checksum>
  <ObjectParts>
    <IsTruncated>boolean</IsTruncated>
    <MaxParts>integer</MaxParts>
    <NextPartNumberMarker>integer</NextPartNumberMarker>
    <PartNumberMarker>integer</PartNumberMarker>
    <Part>
      <ChecksumCRC32>string</ChecksumCRC32>
      <ChecksumCRC32C>string</ChecksumCRC32C>
      <ChecksumSHA1>string</ChecksumSHA1>
      <ChecksumSHA256>string</ChecksumSHA256>
      <PartNumber>integer</PartNumber>
      <Size>integer</Size>
    </Part>
    <PartsCount>integer</PartsCount>
  </ObjectParts>
  <StorageClass>string</StorageClass>
  <ObjectSize>12</ObjectSize>
</GetObjectAttributesOutput>
XML
  end
  let(:s3_attributes_response_headers) do
    {
      'Accept-Ranges': "bytes",
      'Content-Length': s3_attributes_response_body.length,
      'Content-Type': "text/plain",
      'ETag': "6805f2cfc46c0f04559748bb039d69ae",
      'Last-Modified': Time.parse("Thu, 15 Dec 2016 01:19:41 GMT")
    }
  end
  let(:s3_object_response_body) do
    "test_content"
  end
  let(:s3_object_response_headers) do
    response_headers
  end

  it "knows the name of its s3 bucket" do
    expect(s3_query_service.bucket_name).to eq "example-bucket"
  end

  it "converts a doi to an S3 address" do
    expect(s3_query_service.s3_address).to eq "s3://example-bucket/10.34770/pe9w-x904/#{work.id}/"
  end

  it "takes a DOI and returns information about that DOI in S3" do
    fake_aws_client = double(Aws::S3::Client)
    s3_query_service.stub(:client).and_return(fake_aws_client)
    fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output, is_truncated: false)
    fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
    fake_s3_resp.stub(:to_h).and_return(s3_hash)

    data_profile = s3_query_service.data_profile
    expect(data_profile[:objects]).to be_instance_of(Array)
    expect(data_profile[:ok]).to eq true
    expect(data_profile[:objects].count).to eq 2
    expect(data_profile[:objects].first).to be_instance_of(S3File)
    expect(data_profile[:objects].first.filename).to match(/README/)
    expect(data_profile[:objects].first.last_modified).to eq Time.parse("2022-04-21T18:29:40.000Z")
    expect(data_profile[:objects].first.size).to eq 5_368_709_122
  end

  it "takes a DOI and returns information about that DOI in S3 with pagination" do
    fake_aws_client = double(Aws::S3::Client)
    s3_query_service.stub(:client).and_return(fake_aws_client)
    fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output, next_continuation_token: "abc123")
    fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
    fake_s3_resp.stub(:is_truncated).and_return(true, false)
    fake_s3_resp.stub(:to_h).and_return(s3_hash)

    data_profile = s3_query_service.data_profile
    expect(data_profile[:objects]).to be_instance_of(Array)
    expect(data_profile[:ok]).to eq true
    expect(data_profile[:objects].count).to eq 4
    expect(data_profile[:objects].first.filename).to match(/README/)
    expect(data_profile[:objects][1].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
    expect(data_profile[:objects][2].filename).to match(/README/)
    expect(data_profile[:objects][3].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
  end

  it "handles connecting to a bad bucket" do
    fake_aws_client = Aws::S3::Client
    s3_query_service.stub(:client).and_return(fake_aws_client)
    data_profile = s3_query_service.data_profile
    expect(data_profile[:objects]).to be_instance_of(Array)
    expect(data_profile[:ok]).to eq false
  end

  describe "#client" do
    before do
      allow(Aws::S3::Client).to receive(:new)
      s3_query_service.client
    end

    it "constructs the AWS S3 API client object" do
      expect(Aws::S3::Client).to have_received(:new).with(hash_including(region: "us-east-1")).at_least(:once)
    end
  end

  context "with persisted Works" do
    let(:user) { FactoryBot.create(:user) }
    let(:work) { FactoryBot.create(:draft_work, doi:) }
    let(:fake_aws_client) { double(Aws::S3::Client) }
    let(:fake_multi) { instance_double(Aws::S3::Types::CreateMultipartUploadOutput, key: "abc", upload_id: "upload id", bucket: "bucket") }
    let(:fake_parts) { instance_double(Aws::S3::Types::CopyPartResult, etag: "etag123abc", checksum_sha256: "sha256abc123") }
    let(:fake_upload) { instance_double(Aws::S3::Types::UploadPartCopyOutput, copy_part_result: fake_parts) }
    let(:fake_s3_resp) { double(Aws::S3::Types::ListObjectsV2Output, is_truncated: false) }
    let(:preservation_service) { instance_double(WorkPreservationService) }

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
      allow(s3_query_service.client).to receive(:head_object).and_return(true)
      allow(s3_query_service.client).to receive(:complete_multipart_upload).and_return(fake_completion)
      allow(s3_query_service.client).to receive(:put_object).and_return(nil)

      allow(WorkPreservationService).to receive(:new).and_return(preservation_service)
      allow(preservation_service).to receive(:preserve!)
    end

    describe "#publish_files" do
      it "calls moves the files calling create_multipart_upload, head_object, and delete_object twice, once for each file, and called the preservation service" do
        expect do
          expect(s3_query_service.publish_files(user)).to be_truthy
        end.to change { work.upload_snapshots.count }.by 1
        fake_s3_resp.stub(:to_h).and_return(s3_hash, empty_s3_hash)
        snapshot = work.upload_snapshots.first
        expect(snapshot.files).to eq([
                                       { "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_README.txt", "snapshot_id" => snapshot.id, "upload_status" => "started",
                                         "user_id" => user.id, "checksum" => "008eec11c39e7038409739c0160a793a" },
                                       { "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json", "snapshot_id" => snapshot.id, "upload_status" => "started",
                                         "user_id" => user.id, "checksum" => "7bd3d4339c034ebc663b990657714688" }
                                     ])
        perform_enqueued_jobs
        expect(s3_query_service.client).to have_received(:create_multipart_upload)
          .with({ bucket: "example-bucket-post", key: s3_key1, checksum_algorithm: "SHA256" })
        expect(s3_query_service.client).to have_received(:create_multipart_upload)
          .with({ bucket: "example-bucket-post", key: s3_key2, checksum_algorithm: "SHA256" })
        expect(s3_query_service.client).to have_received(:upload_part_copy)
          .with({ bucket: "example-bucket-post", copy_source: "/example-bucket/#{s3_key1}",
                  copy_source_range: "bytes=0-5368709119", key: "abc", part_number: 1, upload_id: "upload id" })
        expect(s3_query_service.client).to have_received(:upload_part_copy)
          .with({ bucket: "example-bucket-post", copy_source: "/example-bucket/#{s3_key1}",
                  copy_source_range: "bytes=5368709120-5368709121", key: "abc", part_number: 2, upload_id: "upload id" })
        expect(s3_query_service.client).to have_received(:upload_part_copy)
          .with({ bucket: "example-bucket-post", copy_source: "/example-bucket/#{s3_key2}",
                  copy_source_range: "bytes=0-5368709119", key: "abc", part_number: 1, upload_id: "upload id" })
        expect(s3_query_service.client).to have_received(:upload_part_copy)
          .with({ bucket: "example-bucket-post", copy_source: "/example-bucket/#{s3_key2}",
                  copy_source_range: "bytes=5368709120-5368709127", key: "abc", part_number: 2, upload_id: "upload id" })
        expect(s3_query_service.client).to have_received(:complete_multipart_upload)
          .with({ bucket: "example-bucket-post", key: s3_key1, multipart_upload: { parts: [{ etag: "etag123abc", part_number: 1, checksum_sha256: "sha256abc123" },
                                                                                           { etag: "etag123abc", part_number: 2, checksum_sha256: "sha256abc123" }] }, upload_id: "upload id" })
        expect(s3_query_service.client).to have_received(:complete_multipart_upload)
          .with({ bucket: "example-bucket-post", key: s3_key2, multipart_upload: { parts: [{ etag: "etag123abc", part_number: 1, checksum_sha256: "sha256abc123" },
                                                                                           { etag: "etag123abc", part_number: 2, checksum_sha256: "sha256abc123" }] }, upload_id: "upload id" })
        expect(s3_query_service.client).to have_received(:head_object)
          .with({ bucket: "example-bucket-post", key: s3_key1 })
        expect(s3_query_service.client).to have_received(:head_object)
          .with({ bucket: "example-bucket-post", key: s3_key2 })
        expect(s3_query_service.client).to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: s3_key1 })
        expect(s3_query_service.client).to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: s3_key2 })
        expect(s3_query_service.client).to have_received(:delete_object)
          .with({ bucket: "example-bucket", key: work.s3_object_key })
        expect(preservation_service).to have_received(:preserve!)
        expect(snapshot.reload.files).to eq([
                                              { "checksum" => "abc123etagetag", "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_README.txt", "snapshot_id" => snapshot.id,
                                                "upload_status" => "complete", "user_id" => user.id },
                                              { "checksum" => "abc123etagetag", "filename" => "10.34770/pe9w-x904/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json",
                                                "snapshot_id" => snapshot.id, "upload_status" => "complete", "user_id" => user.id }
                                            ])
      end
      context "the copy fails for some reason" do
        it "Does not delete anything and returns the missing file" do
          allow(s3_query_service.client).to receive(:head_object).and_return(true, false)
          expect(s3_query_service.publish_files(user)).to be_truthy
          expect { perform_enqueued_jobs }.to raise_error(/File check was not valid/)
          expect(s3_query_service.client).to have_received(:create_multipart_upload)
            .with({ bucket: "example-bucket-post", key: s3_key1, checksum_algorithm: "SHA256" })
          expect(s3_query_service.client).to have_received(:create_multipart_upload)
            .with({ bucket: "example-bucket-post", key: s3_key2, checksum_algorithm: "SHA256" })
          expect(s3_query_service.client).to have_received(:head_object)
            .with({ bucket: "example-bucket-post", key: s3_key1 })
          expect(s3_query_service.client).to have_received(:head_object)
            .with({ bucket: "example-bucket-post", key: s3_key2 })
          expect(s3_query_service.client).to have_received(:delete_object)
            .with({ bucket: "example-bucket", key: s3_key1 })
          expect(s3_query_service.client).not_to have_received(:delete_object)
            .with({ bucket: "example-bucket", key: s3_key2 })
          expect(s3_query_service.client).not_to have_received(:delete_object)
            .with({ bucket: "example-bucket", key: work.s3_object_key })
        end

        it "Does not delete anything and returns both missing files" do
          allow(s3_query_service.client).to receive(:head_object).and_return(false)
          expect(s3_query_service.publish_files(user)).to be_truthy

          # both jobs create an exception
          expect { perform_enqueued_jobs }.to raise_error(/File check was not valid/)
          expect { perform_enqueued_jobs }.to raise_error(/File check was not valid/)

          expect(s3_query_service.client).to have_received(:create_multipart_upload)
            .with({ bucket: "example-bucket-post", key: s3_key1, checksum_algorithm: "SHA256" })
          expect(s3_query_service.client).to have_received(:create_multipart_upload)
            .with({ bucket: "example-bucket-post", key: s3_key2, checksum_algorithm: "SHA256" })
          expect(s3_query_service.client).to have_received(:head_object)
            .with({ bucket: "example-bucket-post", key: s3_key1 })
          expect(s3_query_service.client).to have_received(:head_object)
            .with({ bucket: "example-bucket-post", key: s3_key2 })
          expect(s3_query_service.client).not_to have_received(:delete_object)
            .with({ bucket: "example-bucket", key: s3_key1 })
          expect(s3_query_service.client).not_to have_received(:delete_object)
            .with({ bucket: "example-bucket", key: s3_key2 })
          expect(s3_query_service.client).not_to have_received(:delete_object)
            .with({ bucket: "example-bucket", key: work.s3_object_key })
        end
      end
    end

    describe "#data_profile" do
      context "when an error is encountered requesting the file resources" do
        let(:output) { s3_query_service.data_profile }

        before do
          fake_aws_client.stub(:list_objects_v2).and_raise(StandardError)
          allow(Rails.logger).to receive(:error)
          output
        end

        it "an error is logged" do
          expect(Rails.logger).to have_received(:error).with("Error querying S3. Bucket: example-bucket. DOI: #{doi}. Exception: StandardError")
          expect(output).to eq({ objects: [], ok: false })
        end
      end

      it "takes a DOI and returns information about that DOI in S3" do
        data_profile = s3_query_service.data_profile
        expect(data_profile).to be_a(Hash)
        expect(data_profile).to include(:objects)
        children = data_profile[:objects]

        expect(children.count).to eq 2
        expect(children.first).to be_instance_of(S3File)
        expect(children.first.filename).to eq(s3_key1)

        last_modified = children.first.last_modified
        expect(last_modified.to_s).to eq(s3_last_modified1.to_s)

        expect(children.first.size).to eq(s3_size1)

        expect(children.last).to be_instance_of(S3File)
        expect(children.last.filename).to eq(s3_key2)

        last_modified = children.last.last_modified
        expect(last_modified.to_s).to eq(s3_last_modified2.to_s)

        expect(children.last.size).to eq(s3_size2)
      end
    end

    describe "#file_count" do
      it "returns only the files" do
        expect(s3_query_service.file_count).to eq(2)
      end

      context "when an error is encountered" do
        subject(:s3_query_service) { described_class.new(work) }
        let(:file_count) { s3_query_service.file_count }
        let(:client) { instance_double(Aws::S3::Client) }
        let(:service_error_context) { instance_double(Seahorse::Client::RequestContext) }
        let(:service_error_message) { "test AWS service error" }
        let(:service_error) { Aws::Errors::ServiceError.new(service_error_context, service_error_message) }
        let(:prefix) { "#{work.doi}/#{work.id}/" }

        before do
          allow(Rails.logger).to receive(:error)
          # This needs to be disabled to override the mock set for previous cases
          allow(s3_query_service).to receive(:client).and_call_original
          allow(Aws::S3::Client).to receive(:new).and_return(client)
          allow(client).to receive(:list_objects_v2).and_raise(service_error)
        end

        it "logs the error and re-raises it" do
          s3_query_service = described_class.new(work)
          expect { s3_query_service.file_count }.to raise_error(Aws::Errors::ServiceError)
          expect(Rails.logger).to have_received(:error).with("An error was encountered when requesting AWS S3 Objects from the bucket example-bucket with the prefix #{prefix}: test AWS service error")
        end
      end
    end

    describe "#count_objects" do
      before do
        fake_s3_resp.stub(:key_count).and_return(s3_hash[:key_count])
        fake_s3_resp.stub(:is_truncated).and_return(false)
      end

      it "returns all the objects" do
        expect(s3_query_service.count_objects).to eq(3)
      end

      context "truncated results" do
        before do
          fake_s3_resp.stub(:key_count).and_return(s3_hash[:key_count])
          fake_s3_resp.stub(:is_truncated).and_return(true, false)
          fake_s3_resp.stub(:next_continuation_token).and_return("abc")
        end
        it "returns all the objects" do
          expect(s3_query_service.count_objects).to eq(6)
        end
      end

      context "an empty response" do
        before do
          fake_s3_resp.stub(:key_count).and_return(0)
          fake_s3_resp.stub(:is_truncated).and_return(false)
        end

        it "returns all the objects" do
          expect(s3_query_service.count_objects).to eq(0)
        end
      end
    end
  end

  context "post curated" do
    let(:s3_query_service) { described_class.new(work, "postcuration") }

    it "keeps precurated and post curated items separate" do
      fake_aws_client = double(Aws::S3::Client)
      s3_query_service.stub(:client).and_return(fake_aws_client)
      fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output, is_truncated: false)
      fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
      fake_s3_resp.stub(:to_h).and_return(s3_hash)

      data_profile = s3_query_service.data_profile
      expect(data_profile[:objects]).to be_instance_of(Array)
      expect(data_profile[:ok]).to eq true
      expect(data_profile[:objects].count).to eq 2
      expect(data_profile[:objects].first).to be_instance_of(S3File)
      expect(data_profile[:objects].first.filename).to match(/README/)
      expect(data_profile[:objects].first.last_modified).to eq Time.parse("2022-04-21T18:29:40.000Z")
      expect(data_profile[:objects].first.size).to eq 5_368_709_122
    end
  end
  let(:response_headers) do
    {
      'Accept-Ranges': "bytes",
      'Content-Length': 12,
      'Content-Type': "text/plain",
      'ETag': "6805f2cfc46c0f04559748bb039d69ae",
      'Last-Modified': Time.parse("Thu, 15 Dec 2016 01:19:41 GMT")
    }
  end

  describe "#get_s3_object" do
    subject(:s3_query_service) { described_class.new(work) }
    let(:key) { "test_key" }
    let(:s3_object) { s3_query_service.get_s3_object(key:) }

    before do
      stub_request(:get, "https://example-bucket.s3.amazonaws.com/test_key?attributes").to_return(status: 200, body: s3_attributes_response_body, headers: s3_attributes_response_headers)
      stub_request(:get, "https://example-bucket.s3.amazonaws.com/test_key").to_return(status: 200, body: s3_object_response_body, headers: s3_object_response_headers)
    end

    it "retrieves the S3 Object from the HTTP API" do
      expect(s3_object).not_to be nil
      bytestream = s3_object[:body]
      expect(bytestream.read).to eq("test_content")
    end

    context "when an error is encountered" do
      subject(:s3_query_service) { described_class.new(work) }
      let(:file_count) { s3_query_service.file_count }
      let(:client) { instance_double(Aws::S3::Client) }
      let(:service_error_context) { instance_double(Seahorse::Client::RequestContext) }
      let(:service_error_message) { "test AWS service error" }
      let(:service_error) { Aws::Errors::ServiceError.new(service_error_context, service_error_message) }
      let(:prefix) { "#{work.doi}/#{work.id}/" }

      before do
        allow(Rails.logger).to receive(:error)
        # This needs to be disabled to override the mock set for previous cases
        allow(s3_query_service).to receive(:client).and_call_original
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        allow(client).to receive(:get_object).and_raise(service_error)
      end

      it "logs and re-raises the error" do
        s3_query_service = described_class.new(work)
        expect { s3_query_service.get_s3_object(key:) }.to raise_error(Aws::Errors::ServiceError)
        expect(Rails.logger).to have_received(:error).with("An error was encountered when requesting the AWS S3 Object test_key: test AWS service error")
      end
    end
  end

  describe "#delete_s3_object" do
    let(:response_headers) do
      {
        'Accept-Ranges': "bytes",
        'Content-Length': 71,
        'Content-Type': "text/plain",
        'ETag': "6805f2cfc46c0f04559748bb039d69ae",
        'Last-Modified': Time.parse("Thu, 15 Dec 2016 01:19:41 GMT")
      }
    end

    subject(:s3_query_service) { described_class.new(work) }
    let(:s3_file) { FactoryBot.build :s3_file, filename: "test_key" }

    before do
      stub_request(:delete, "https://example-bucket.s3.amazonaws.com/test_key").to_return(status: 200)
    end

    it "retrieves the S3 Object from the HTTP API" do
      s3_query_service.delete_s3_object(s3_file.key)
      assert_requested(:delete, "https://example-bucket.s3.amazonaws.com/test_key")
    end

    context "when an error is encountered" do
      subject(:s3_query_service) { described_class.new(work) }
      let(:client) { instance_double(Aws::S3::Client) }
      let(:service_error_context) { instance_double(Seahorse::Client::RequestContext) }
      let(:service_error_message) { "test AWS service error" }
      let(:service_error) { Aws::Errors::ServiceError.new(service_error_context, service_error_message) }
      let(:prefix) { "#{work.doi}/#{work.id}/" }

      before do
        allow(Rails.logger).to receive(:error)
        # This needs to be disabled to override the mock set for previous cases
        allow(s3_query_service).to receive(:client).and_call_original
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        allow(client).to receive(:delete_object).and_raise(service_error)
      end

      it "logs and re-raises the error" do
        s3_query_service = described_class.new(work)
        expect { s3_query_service.delete_s3_object(s3_file.key) }.to raise_error(Aws::Errors::ServiceError)
        expect(Rails.logger).to have_received(:error).with("An error was encountered when requesting to delete the AWS S3 Object test_key in the bucket example-bucket: test AWS service error")
      end
    end
  end

  describe "#find_s3_file" do
    subject(:s3_query_service) { described_class.new(work) }
    let(:filename) { "test.txt" }
    let(:s3_file) { s3_query_service.find_s3_file(filename:) }

    before do
      stub_request(:get, "https://example-bucket.s3.amazonaws.com/10.34770/pe9w-x904/#{work.id}/test.txt").to_return(
        headers: s3_object_response_headers,
        status: 200,
        body: s3_object_response_body
      )

      stub_request(:get, "https://example-bucket.s3.amazonaws.com/10.34770/pe9w-x904/#{work.id}/test.txt?attributes").to_return(
        headers: s3_attributes_response_headers,
        status: 200, body: s3_attributes_response_body
      )
    end

    it "retrieves the S3File from the AWS Bucket" do
      expect(s3_file).not_to be nil
      expect(s3_file.filename).to eq("10.34770/pe9w-x904/#{work.id}/test.txt")
      expect(s3_file.last_modified).to be_a(Time)
      expect(s3_file.size).to eq(12)
      expect(s3_file.checksum).to eq(s3_etag1)

      assert_requested(:get, "https://example-bucket.s3.amazonaws.com/10.34770/pe9w-x904/#{work.id}/test.txt?attributes")
    end
  end

  describe "#file_url" do
    subject(:s3_query_service) { described_class.new(work) }

    let(:signer) { instance_double(Aws::S3::Presigner) }
    let(:object_attributes) do
      {}
    end

    it "creates a presigned url" do
      allow(Aws::S3::Presigner).to receive(:new).and_return(signer)
      allow(signer).to receive(:presigned_url).and_return("aws_url")
      expect(s3_query_service.file_url("test_key")).to eq("aws_url")
      expect(signer).to have_received(:presigned_url).with(:get_object, { bucket: "example-bucket", key: "test_key" }).once
    end
  end

  describe "#create_directory" do
    subject(:s3_query_service) { described_class.new(work) }

    before do
      stub_request(:put, "https://example-bucket.s3.amazonaws.com/#{s3_query_service.prefix}").to_return(status: 200)
    end

    it "creates a directory" do
      s3_query_service.create_directory
      assert_requested(:put, "https://example-bucket.s3.amazonaws.com/#{s3_query_service.prefix}", headers: { "Content-Length" => 0 })
    end

    context "when an error is encountered" do
      subject(:s3_query_service) { described_class.new(work) }
      let(:client) { instance_double(Aws::S3::Client) }
      let(:service_error_context) { instance_double(Seahorse::Client::RequestContext) }
      let(:service_error_message) { "test AWS service error" }
      let(:service_error) { Aws::Errors::ServiceError.new(service_error_context, service_error_message) }
      let(:prefix) { "#{work.doi}/#{work.id}/" }

      before do
        allow(Rails.logger).to receive(:error)
        # This needs to be disabled to override the mock set for previous cases
        allow(s3_query_service).to receive(:client).and_call_original
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        allow(client).to receive(:put_object).and_raise(service_error)
      end

      it "logs and re-raises the error" do
        s3_query_service = described_class.new(work)
        expect { s3_query_service.create_directory }.to raise_error(Aws::Errors::ServiceError)
        # rubocop:disable Layout/LineLength
        expect(Rails.logger).to have_received(:error).with("An error was encountered when requesting to create the AWS S3 directory Object in the bucket example-bucket with the key #{prefix}: test AWS service error")
        # rubocop:enable Layout/LineLength
      end
    end
  end

  describe "#upload_file" do
    subject(:s3_query_service) { described_class.new(work) }
    let(:filename) { "README.txt" }
    let(:file) { File.open(Rails.root.join("spec", "fixtures", "files", "readme_template.txt")) }

    before do
      stub_request(:put, "https://example-bucket.s3.amazonaws.com/#{s3_query_service.prefix}#{filename}").to_return(status: 200)
    end

    it "uploads the readme" do
      expect(s3_query_service.upload_file(io: file, filename:, size: 2852)).to eq("10.34770/pe9w-x904/#{work.id}/README.txt")
      assert_requested(:put, "https://example-bucket.s3.amazonaws.com/#{s3_query_service.prefix}#{filename}", headers: { "Content-Length" => 2852 })
    end

    context "when the file is large" do
      let(:fake_aws_client) { double(Aws::S3::Client) }
      let(:fake_multi) { instance_double(Aws::S3::Types::CreateMultipartUploadOutput, key: "abc", upload_id: "upload id", bucket: "bucket") }
      let(:fake_upload) { instance_double(Aws::S3::Types::UploadPartOutput, etag: "etag123abc") }
      let(:fake_completion) { instance_double(Seahorse::Client::Response, "successful?": true) }
      let(:key) { "10.34770/pe9w-x904/#{work.id}/README.txt" }

      before do
        s3_query_service.stub(:client).and_return(fake_aws_client)
        allow(s3_query_service.client).to receive(:create_multipart_upload).and_return(fake_multi)
        allow(s3_query_service.client).to receive(:upload_part).and_return(fake_upload)
        allow(s3_query_service.client).to receive(:complete_multipart_upload).and_return(fake_completion)
      end

      it "uploads the large file" do
        expect(s3_query_service.upload_file(io: file, filename:, size: 6_000_000_000)).to eq(key)
        expect(s3_query_service.client).to have_received(:create_multipart_upload)
          .with({ bucket: "example-bucket", key: })
        expect(s3_query_service.client).to have_received(:upload_part)
          .with(hash_including(bucket: "example-bucket", key: "abc", part_number: 1, upload_id: "upload id"))
        expect(s3_query_service.client).to have_received(:upload_part)
          .with(hash_including(bucket: "example-bucket", key: "abc", part_number: 2, upload_id: "upload id"))
        expect(s3_query_service.client).to have_received(:complete_multipart_upload)
          .with({ bucket: "example-bucket", key:, multipart_upload: { parts: [{ etag: "etag123abc", part_number: 1 },
                                                                              { etag: "etag123abc", part_number: 2 }] }, upload_id: "upload id" })
      end
    end

    context "when checksum does not match" do
      before do
        stub_request(:put, "https://example-bucket.s3.amazonaws.com/#{s3_query_service.prefix}#{filename}").to_raise(Aws::S3::Errors::SignatureDoesNotMatch.new(nil, nil))
      end

      it "detects the upload error" do
        expect(s3_query_service.upload_file(io: file, filename:, size: 2852)).to be_falsey
        assert_requested(:put, "https://example-bucket.s3.amazonaws.com/#{s3_query_service.prefix}#{filename}", headers: { "Content-Length" => 2852 })
      end
    end

    context "when an error is encountered" do
      subject(:s3_query_service) { described_class.new(work) }
      let(:file_count) { s3_query_service.file_count }
      let(:client) { instance_double(Aws::S3::Client) }
      let(:service_error_context) { instance_double(Seahorse::Client::RequestContext) }
      let(:service_error_message) { "test AWS service error" }
      let(:service_error) { Aws::Errors::ServiceError.new(service_error_context, service_error_message) }
      let(:prefix) { "#{work.doi}/#{work.id}/" }

      before do
        allow(Rails.logger).to receive(:error)
        # This needs to be disabled to override the mock set for previous cases
        allow(s3_query_service).to receive(:client).and_call_original
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        allow(client).to receive(:put_object).and_raise(service_error)
      end

      it "logs and re-raises the error" do
        s3_query_service = described_class.new(work)
        expect do
          s3_query_service.upload_file(io: file, filename:, size: 2852)
        end.to raise_error(Aws::Errors::ServiceError)
        # rubocop:disable Layout/LineLength
        expect(Rails.logger).to have_received(:error).with("An error was encountered when requesting to create the AWS S3 Object in the bucket example-bucket with the key #{prefix}README.txt: test AWS service error")
        # rubocop:enable Layout/LineLength
      end
    end
  end

  describe "#client_s3_files" do
    let(:fake_aws_client) { double(Aws::S3::Client) }

    before do
      s3_query_service.stub(:client).and_return(fake_aws_client)
      fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output, next_continuation_token: "abc123")
      fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
      fake_s3_resp.stub(:is_truncated).and_return(true, false, true, false)
      fake_s3_resp.stub(:to_h).and_return(s3_hash)
    end

    it "it retrieves the files for the work" do
      files = s3_query_service.client_s3_files
      expect(files.count).to eq 4
      expect(files.first.filename).to match(/README/)
      expect(files[1].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
      expect(files[2].filename).to match(/README/)
      expect(files[3].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "example-bucket", max_keys: 1000, prefix: "10.34770/pe9w-x904/#{work.id}/")
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "example-bucket", continuation_token: "abc123", max_keys: 1000, prefix: "10.34770/pe9w-x904/#{work.id}/")
    end

    it "it retrieves the files for a bucket and prefix once" do
      s3_query_service.client_s3_files(bucket_name: "other-bucket", prefix: "new-prefix")
      files = s3_query_service.client_s3_files(bucket_name: "other-bucket", prefix: "new-prefix")
      expect(files.count).to eq 4
      expect(files.first.filename).to match(/README/)
      expect(files[1].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
      expect(files[2].filename).to match(/README/)
      expect(files[3].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", max_keys: 1000, prefix: "new-prefix").once
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", continuation_token: "abc123", max_keys: 1000, prefix: "new-prefix").once
    end

    it "it retrieves the files for a bucket and prefix any time reload is true" do
      s3_query_service.client_s3_files(reload: true, bucket_name: "other-bucket", prefix: "new-prefix")
      files = s3_query_service.client_s3_files(reload: true, bucket_name: "other-bucket", prefix: "new-prefix")
      expect(files.count).to eq 4
      expect(files.first.filename).to match(/README/)
      expect(files[1].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
      expect(files[2].filename).to match(/README/)
      expect(files[3].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", max_keys: 1000, prefix: "new-prefix").twice
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", continuation_token: "abc123", max_keys: 1000, prefix: "new-prefix").twice
    end

    it "retrieves the directories if requested" do
      files = s3_query_service.client_s3_files(reload: true, bucket_name: "other-bucket", prefix: "new-prefix", ignore_directories: false)
      expect(files.count).to eq 6
      expect(files[0].filename).to match(/README/)
      expect(files[1].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
      expect(files[2].filename).to match(/directory/)
      expect(files[3].filename).to match(/README/)
      expect(files[4].filename).to match(/SCoData_combined_v1_2020-07_datapackage.json/)
      expect(files[5].filename).to match(/directory/)
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", max_keys: 1000, prefix: "new-prefix")
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", continuation_token: "abc123", max_keys: 1000, prefix: "new-prefix")
    end
  end

  describe "#client_s3_empty_files" do
    let(:fake_aws_client) { double(Aws::S3::Client) }
    let(:s3_size2) { 0 }

    before do
      s3_query_service.stub(:client).and_return(fake_aws_client)
      fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output, next_continuation_token: "abc123")
      fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
      fake_s3_resp.stub(:is_truncated).and_return(true, false, true, false)
      fake_s3_resp.stub(:to_h).and_return(s3_hash)
    end

    it "it retrieves the files for the work" do
      files = s3_query_service.client_s3_empty_files
      expect(files.count).to eq 2
      expect(files.first.filename).to eq(s3_key2)
      expect(files[1].filename).to match(s3_key2)
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "example-bucket", max_keys: 1000, prefix: "10.34770/pe9w-x904/#{work.id}/")
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "example-bucket", continuation_token: "abc123", max_keys: 1000, prefix: "10.34770/pe9w-x904/#{work.id}/")
    end

    it "it retrieves the files for a bucket and prefix once" do
      s3_query_service.client_s3_empty_files(bucket_name: "other-bucket", prefix: "new-prefix")
      files = s3_query_service.client_s3_empty_files(bucket_name: "other-bucket", prefix: "new-prefix")
      expect(files.count).to eq 2
      expect(files.first.filename).to eq(s3_key2)
      expect(files[1].filename).to eq(s3_key2)
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", max_keys: 1000, prefix: "new-prefix").once
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", continuation_token: "abc123", max_keys: 1000, prefix: "new-prefix").once
    end

    it "it retrieves the files for a bucket and prefix any time reload is true" do
      s3_query_service.client_s3_empty_files(reload: true, bucket_name: "other-bucket", prefix: "new-prefix")
      files = s3_query_service.client_s3_empty_files(reload: true, bucket_name: "other-bucket", prefix: "new-prefix")
      expect(files.count).to eq 2
      expect(files.first.filename).to eq(s3_key2)
      expect(files[1].filename).to eq(s3_key2)
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", max_keys: 1000, prefix: "new-prefix").twice
      expect(fake_aws_client).to have_received(:list_objects_v2).with(bucket: "other-bucket", continuation_token: "abc123", max_keys: 1000, prefix: "new-prefix").twice
    end
  end

  describe "#copy_directory" do
    let(:fake_aws_client) { double(Aws::S3::Client) }
    let(:fake_completion) { instance_double(Seahorse::Client::Response, "successful?": true) }

    before do
      s3_query_service.stub(:client).and_return(fake_aws_client)
      fake_aws_client.stub(:copy_object).and_return(fake_completion)
    end

    it "copies the directory calling copy_object" do
      expect(s3_query_service.copy_directory(target_bucket: "example-bucket-post", source_key: "source-key", target_key: "other-bucket/target-key")).to eq(fake_completion)
      expect(s3_query_service.client).to have_received(:copy_object).with(bucket: "example-bucket-post", copy_source: "source-key", key: "other-bucket/target-key")
    end

    context "when an error is encountered" do
      subject(:s3_query_service) { described_class.new(work) }
      let(:file_count) { s3_query_service.file_count }
      let(:client) { instance_double(Aws::S3::Client) }
      let(:service_error_context) { instance_double(Seahorse::Client::RequestContext) }
      let(:service_error_message) { "test AWS service error" }
      let(:service_error) { Aws::Errors::ServiceError.new(service_error_context, service_error_message) }
      let(:prefix) { "#{work.doi}/#{work.id}/" }

      before do
        allow(Rails.logger).to receive(:error)
        # This needs to be disabled to override the mock set for previous cases
        allow(s3_query_service).to receive(:client).and_call_original
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        allow(client).to receive(:copy_object).and_raise(service_error)
      end

      it "logs and re-raises the error" do
        s3_query_service = described_class.new(work)
        expect do
          s3_query_service.copy_directory(target_bucket: "example-bucket-post", source_key: "source-key", target_key: "other-bucket/target-key")
        end.to raise_error(Aws::Errors::ServiceError)
        # rubocop:disable Layout/LineLength
        expect(Rails.logger).to have_received(:error).with("An error was encountered when requesting to copy the AWS S3 directory Object from source-key to other-bucket/target-key in the bucket example-bucket-post: test AWS service error")
        # rubocop:enable Layout/LineLength
      end
    end
  end

  context "when there are empty files" do
    let(:user) { FactoryBot.create(:user) }
    let(:work) { FactoryBot.create(:draft_work, doi:) }
    let(:s3_list_url) { "https://example-bucket.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=#{work.doi}/#{work.id}/" }
    let(:s3_list_response_xml) do
      path = Rails.root.join("spec", "fixtures", "s3_list_bucket_empty_result.xml")
      File.read(path)
    end

    before do
      work
      stub_request(:get, s3_list_url).to_return(status: 200, body: s3_list_response_xml)
      s3_query_service.publish_files(user)
    end

    describe "#publish_files" do
      it "creates a work activity identifying the empty files" do
        work.reload
        expect(work.work_activity.length).to eq(1)
        activity = work.work_activity.first
        work_doi = work.doi.sub(/[^A-Za-z\d]/, "-")
        expect(activity.message).to eq("Warning: Attempted to publish empty S3 file #{work_doi}/SCoData_combined_v1_2020-07_README.empty.txt.")
        expect(work.uploads.length).to eq(2)
        expect(work.uploads.first.filename).to eq("#{work_doi}/SCoData_combined_v1_2020-07_README.txt")
        expect(work.uploads.last.filename).to eq("#{work_doi}/SCoData_combined_v1_2020-07_datapackage.json")
      end
    end
  end
end
