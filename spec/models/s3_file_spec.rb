# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3File, type: :model do
  subject(:s3_file) { described_class.new(filename: filename, last_modified: last_modified, size: size, checksum: checksum, query_service: query_service) }
  let(:filename) { "10-34770/pe9w-x904/SCoData_combined_v1_2020-07_README.txt" }
  let(:last_modified) { Time.parse("2022-04-21T18:29:40.000Z") }
  let(:size) { 10_759 }
  let(:checksum) { "abc123" }
  let(:query_service) { instance_double(S3QueryService, class: S3QueryService, bucket_name: bucket_name) }
  let(:bucket_name) { "test-bucket" }
  let(:url_protocol) { "https" }
  let(:s3_host) { "s3.amazon.com" }

  before do
    allow(S3QueryService).to receive(:url_protocol).and_return(url_protocol)
    allow(S3QueryService).to receive(:s3_host).and_return(s3_host)
  end

  it "can take S3 file data at creation time" do
    expect(s3_file.filename).to eq filename
    expect(s3_file.last_modified).to eq last_modified
    expect(s3_file.size).to eq size
    expect(s3_file.checksum).to eq checksum
  end

  context "checksum with quotes" do
    let(:checksum) { "\"abc123\"" }
    it "removes the quotes in the checksum" do
      expect(s3_file.checksum).to eq "abc123"
    end
  end

  describe "#bucket_name" do
    it "accesses the name of the S3 Bucket" do
      expect(s3_file.bucket_name).to eq(bucket_name)
    end
  end

  describe "#url_protocol" do
    it "accesses the HTTP protocol for the S3 URL" do
      expect(s3_file.url_protocol).to eq(url_protocol)
    end
  end

  describe "#s3_host" do
    it "accesses the host name for the S3 endpoint" do
      expect(s3_file.s3_host).to eq(s3_host)
    end
  end

  describe "#uri" do
    it "builds the URI for the S3 endpoint" do
      expect(s3_file.uri).to be_a(URI)
      expect(s3_file.uri.to_s).to eq("https://test-bucket.#{s3_host}/#{filename}")
    end
  end

  describe "#url" do
    it "builds the URL for the S3 endpoint" do
      expect(s3_file.url).to eq("https://test-bucket.#{s3_host}/#{filename}")
    end
  end

  context "when #query_service is nil" do
    let(:query_service) { nil }
    describe "#bucket_name" do
      it "accesses the name of the S3 Bucket" do
        expect(s3_file.bucket_name).to be nil
      end
    end

    describe "#url_protocol" do
      it "accesses the HTTP protocol for the S3 URL" do
        expect(s3_file.url_protocol).to be nil
      end
    end

    describe "#s3_host" do
      it "accesses the host name for the S3 endpoint" do
        expect(s3_file.s3_host).to be nil
      end
    end

    describe "#uri" do
      it "builds the URI for the S3 endpoint" do
        expect(s3_file.uri).to be nil
      end
    end

    describe "#url" do
      it "builds the URL for the S3 endpoint" do
        expect(s3_file.url).to be nil
      end
    end
  end
end
