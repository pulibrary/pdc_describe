# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULS3Client do
  describe "initialize mode" do
    it "returns the correct config for PRECURATION" do
      s3 = described_class.new(PULS3Client::PRECURATION)
      expect(s3.config[:bucket]).to eq("example-bucket")
    end

    it "returns the correct config for POSTCURATION" do
      s3 = described_class.new(PULS3Client::POSTCURATION)
      expect(s3.config[:bucket]).to eq("example-bucket-post")
    end

    it "returns the correct config for PRESERVATION" do
      s3 = described_class.new(PULS3Client::PRESERVATION)
      expect(s3.config[:bucket]).to eq("example-bucket-preservation")
    end

    it "returns the correct config for EMBARGO" do
      s3 = described_class.new(PULS3Client::EMBARGO)
      expect(s3.config[:bucket]).to eq("example-bucket-embargo")
    end

    it "raises and error for other names" do
      s3 = described_class.new("other")
      expect { s3.config }.to raise_error "Invalid mode value: other"
    end
  end

  describe "#upload_file" do
    let(:pul_s3_client) { described_class.new(PULS3Client::PRECURATION) }
    let(:file) { File.open(Rails.root.join("spec", "fixtures", "files", "readme_template.txt")) }
    let(:key) { "10.34770/pe9w-x904/work_id/README.txt" }

    before do
      stub_request(:put, "https://example-bucket.s3.amazonaws.com/#{key}").to_return(status: 200)
    end

    it "uploads the readme to the bucket" do
      expect(pul_s3_client.upload_file(io: file, target_key: key, size: 2852)).to eq(key)
      assert_requested(:put, "https://example-bucket.s3.amazonaws.com/#{key}", headers: { "Content-Length" => 2852 })
    end

    context "when the bucket is embargo" do
      let(:pul_s3_client) { described_class.new(PULS3Client::EMBARGO) }
      before do
        stub_request(:put, "https://example-bucket-embargo.s3.amazonaws.com/#{key}").to_return(status: 200)
      end

      it "uploads the readme to the bucket" do
        expect(pul_s3_client.upload_file(io: file, target_key: key, size: 2852)).to eq(key)
        assert_requested(:put, "https://example-bucket-embargo.s3.amazonaws.com/#{key}", headers: { "Content-Length" => 2852 })
      end
    end

    context "when checksum does not match" do
      before do
        stub_request(:put, "https://example-bucket.s3.amazonaws.com/#{key}").to_raise(Aws::S3::Errors::SignatureDoesNotMatch.new(nil, nil))
      end

      it "detects the upload error" do
        expect(pul_s3_client.upload_file(io: file, target_key: key, size: 2852)).to be_falsey
        assert_requested(:put, "https://example-bucket.s3.amazonaws.com/#{key}", headers: { "Content-Length" => 2852 })
      end
    end

    context "when an error is encountered" do
      let(:fake_aws_client) { instance_double(Aws::S3::Client) }
      let(:service_error_context) { instance_double(Seahorse::Client::RequestContext) }
      let(:service_error_message) { "test AWS service error" }
      let(:service_error) { Aws::Errors::ServiceError.new(service_error_context, service_error_message) }

      before do
        allow(Rails.logger).to receive(:error)
        # This needs to be disabled to override the mock set for previous cases
        allow(pul_s3_client).to receive(:client).and_call_original
        allow(Aws::S3::Client).to receive(:new).and_return(fake_aws_client)
        allow(fake_aws_client).to receive(:put_object).and_raise(service_error)
      end

      it "logs and re-raises the error" do
        s3_query_service = described_class.new(PULS3Client::PRECURATION)
        expect do
          s3_query_service.upload_file(io: file, target_key: key, size: 2852)
        end.to raise_error(Aws::Errors::ServiceError)
        # rubocop:disable Layout/LineLength
        expect(Rails.logger).to have_received(:error).with("An error was encountered when requesting to create the AWS S3 Object in the bucket example-bucket with the key #{key}: test AWS service error")
        # rubocop:enable Layout/LineLength
      end
    end

    context "When the file is large" do
      let(:pul_s3_client) { described_class.new(PULS3Client::PRECURATION) }
      let(:file) { File.open(Rails.root.join("spec", "fixtures", "files", "readme_template.txt")) }
      let(:fake_aws_client) { double(Aws::S3::Client) }
      let(:fake_multi) { instance_double(Aws::S3::Types::CreateMultipartUploadOutput, key: "abc", upload_id: "upload id", bucket: "bucket") }
      let(:fake_upload) { instance_double(Aws::S3::Types::UploadPartOutput, etag: "etag123abc") }
      let(:fake_completion) { instance_double(Seahorse::Client::Response, "successful?": true) }
      let(:key) { "10.34770/pe9w-x904/work_id/README.txt" }

      before do
        pul_s3_client.stub(:client).and_return(fake_aws_client)
        allow(pul_s3_client.client).to receive(:create_multipart_upload).and_return(fake_multi)
        allow(pul_s3_client.client).to receive(:upload_part).and_return(fake_upload)
        allow(pul_s3_client.client).to receive(:complete_multipart_upload).and_return(fake_completion)
      end

      it "uploads the large file" do
        expect(pul_s3_client.upload_file(io: file, target_key: key, size: 6_000_000_000)).to eq(key)
        expect(pul_s3_client.client).to have_received(:create_multipart_upload)
          .with({ bucket: "example-bucket", key: })
        expect(pul_s3_client.client).to have_received(:upload_part)
          .with(hash_including(bucket: "example-bucket", key: "abc", part_number: 1, upload_id: "upload id"))
        expect(pul_s3_client.client).to have_received(:upload_part)
          .with(hash_including(bucket: "example-bucket", key: "abc", part_number: 2, upload_id: "upload id"))
        expect(pul_s3_client.client).to have_received(:complete_multipart_upload)
          .with({ bucket: "example-bucket", key:, multipart_upload: { parts: [{ etag: "etag123abc", part_number: 1 },
                                                                              { etag: "etag123abc", part_number: 2 }] }, upload_id: "upload id" })
      end
    end
  end
end
