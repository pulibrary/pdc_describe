# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3File, type: :model do
  subject(:s3_file) { described_class.new(filename: filename, last_modified: last_modified, size: size, checksum: checksum, query_service: query_service) }
  let(:filename) { "10-34770/pe9w-x904/filename [with spaces] wéî®∂ chars.txt" }
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

  describe "#globus_url" do
    it "builds the URL for the S3 endpoint" do
      expect(s3_file.globus_url).to match(%r{^https://example.data.globus.org/10-34770/pe9w-x904/filename})
      url_file = s3_file.globus_url.split("/").last
      expect(url_file).to eq("filename+%5Bwith+spaces%5D+w%C3%A9%C3%AE%C2%AE%E2%88%82+chars.txt")
      expect(CGI.unescape(url_file)).to eq(filename.split("/").last)
    end
  end

  describe "#to_blob" do
    let(:file) do
      S3File.new(
        filename: "abc123/111/SCoData_combined_v1_2020-07_README.txt",
        last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
        size: 12_739,
        checksum: "abc567"
      )
    end

    it "persists S3 Bucket resources as ActiveStorage::Blob" do
      # call the s3 reload and make sure no more files get added to the model
      blob = nil
      expect { blob = file.to_blob }.to change { ActiveStorage::Blob.count }.by(1)

      expect(blob.key).to eq("abc123/111/SCoData_combined_v1_2020-07_README.txt")
    end

    context "a blob already exists for one of the files" do
      before do
        persisted = ActiveStorage::Blob.create_before_direct_upload!(
          filename: file.filename, content_type: "", byte_size: file.size, checksum: ""
        )
        persisted.key = file.filename
        persisted.save
      end

      it "finds the blob" do
        expect { file.to_blob }.to change { ActiveStorage::Blob.count }.by(0)
      end
    end
  end
end
