# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkPreservationService do
  describe "preserve in S3" do
    let(:approved_work) { FactoryBot.create :approved_work, doi: "10.34770/pe9w-x904" }
    let(:path) { approved_work.s3_query_service.prefix }
    let(:preservation_directory) { path + "princeton_data_commons/" }
    let(:file1) { FactoryBot.build :s3_file, filename: "#{approved_work.doi}/#{approved_work.id}/anyfile1.txt", last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
    let(:file2) { FactoryBot.build :s3_file, filename: "#{approved_work.doi}/#{approved_work.id}/folder1/anyfile2.txt", last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
    let(:preservation_file1) do
      FactoryBot.build(
        :s3_file,
        filename: "#{approved_work.doi}/#{approved_work.id}//princeton_data_commons/metadata.json",
        last_modified: Time.parse("2022-04-21T18:29:40.000Z")
      )
    end
    let(:files) { [file1, file2, preservation_file1] }
    let(:fake_s3_service) { stub_s3(data: files, bucket_name: "example-bucket-preservation", prefix: "10.34770/pe9w-x904/#{approved_work.id}/") }

    before do
      allow(fake_s3_service.s3client).to receive(:upload_file).and_return(true)
    end

    it "preserves a work to the indicated location in S3" do
      subject = described_class.new(work_id: approved_work.id, path:)
      expect(subject.preserve!).to eq "s3://example-bucket-preservation/#{preservation_directory}"
      expect(fake_s3_service.s3client).to have_received(:upload_file).with(target_key: "10.34770/pe9w-x904/#{approved_work.id}/princeton_data_commons/metadata.json", size: anything, io: anything)
      expect(fake_s3_service.s3client).to have_received(:upload_file).with(target_key: "10.34770/pe9w-x904/#{approved_work.id}/princeton_data_commons/datacite.xml", size: anything, io: anything)
      expect(fake_s3_service.s3client).to have_received(:upload_file).with(target_key: "10.34770/pe9w-x904/#{approved_work.id}/princeton_data_commons/provenance.json", size: anything, io: anything)
    end

    it "excludes the preservation files from the preservation metadata" do
      subject = described_class.new(work_id: approved_work.id, path:)
      metadata = JSON.parse(subject.preservation_metadata)
      expect(metadata["files"].any? { |file| file["filename"] == file1.filename }).to be true
      expect(metadata["files"].any? { |file| file["filename"] == file2.filename }).to be true
      expect(metadata["files"].any? { |file| file["filename"] == preservation_file1.filename }).to be false
    end
  end

  describe "preserve locally" do
    let(:approved_work) { FactoryBot.create :approved_work, doi: "10.34770/pe9w-x904" }
    let(:path) { approved_work.s3_query_service.prefix }
    let(:local_path) { "./tmp/" + path }

    before do
      stub_s3
    end

    it "preserves a work locally" do
      subject = described_class.new(work_id: approved_work.id, path: local_path, localhost: true)
      location = subject.preserve!
      expect(location.start_with?("file:///")).to be true
      expect(location.end_with?("#{local_path}princeton_data_commons/")).to be true
    end
  end
end
