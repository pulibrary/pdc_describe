# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3File, type: :model do
  subject(:s3_file) { described_class.new(filename:, last_modified:, size:, checksum:, work:) }

  let(:work) { FactoryBot.create(:draft_work, doi: "10.99999/123-abc") }
  let(:filename) { "#{work.doi}/#{work.id}/filename [with spaces] wéî®∂ chars.txt" }
  let(:last_modified) { Time.parse("2022-04-21T18:29:40.000Z") }
  let(:size) { 10_759 }
  let(:checksum) { "abc123" }
  let(:query_service) { instance_double(S3QueryService, class: S3QueryService, bucket_name:) }
  let(:bucket_name) { "test-bucket" }

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

  context "filename and filename display" do
    it "preserves path where appropriate" do
      expect(s3_file.filename).to eq "#{work.doi}/#{work.id}/filename [with spaces] wéî®∂ chars.txt"
      expect(s3_file.filename_display).to eq "filename [with spaces] wéî®∂ chars.txt"
    end
  end

  context "display file size" do
    it "uses 1000 base" do
      expect(s3_file.display_size).to eq "10.8 KB"
      # expect(number_to_human_size(size)).to eq "10.8 KB"
    end
   
  end

  context "safe_id" do
    it "calculates correct safe_id for files with spaces and non-alpha numeric characters" do
      expect(s3_file.safe_id).to eq "10-99999-123-abc-#{work.id}-filename--with-spaces--w-----chars-txt"
    end
  end

  describe "#globus_url" do
    it "builds the URL for the S3 endpoint" do
      expect(s3_file.globus_url).to match(%r{^https://example.data.globus.org/#{work.doi}/#{work.id}/filename})
      url_file = s3_file.globus_url.split("/").last
      expect(url_file).to eq("filename%20%5Bwith%20spaces%5D%20w%C3%A9%C3%AE%C2%AE%E2%88%82%20chars.txt")
      expect(CGI.unescape(url_file)).to eq(filename.split("/").last)
    end
  end

  describe "#create_snapshot" do
    let(:s3_file) do
      S3File.new(
        filename: "SCoData_combined_v1_2020-07_README.txt",
        last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
        size: 12_739,
        checksum: "abc567",
        work:
      )
    end
    let(:s3_client) { instance_double(Aws::S3::Client) }
    let(:s3_query_service) { instance_double(S3QueryService) }
    let(:bitstream) { instance_double(ActiveStorage::Attached::One) }
    let(:upload_snapshot) { instance_double(UploadSnapshot) }

    before do
      allow(s3_client).to receive(:copy_object)
      allow(work.s3_query_service).to receive(:client).and_return(s3_client)

      allow(upload_snapshot).to receive(:reload)
      allow(upload_snapshot).to receive(:save)
      allow(upload_snapshot).to receive(:upload=)
      allow(UploadSnapshot).to receive(:create).and_return(upload_snapshot)

      allow(Rails.logger).to receive(:info)

      s3_file.create_snapshot
    end

    it "creates an UploadSnapshot" do
      expect(upload_snapshot).to have_received(:upload=)
      expect(upload_snapshot).to have_received(:save)
      expect(upload_snapshot).to have_received(:reload)
    end
  end
end
