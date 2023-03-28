# frozen_string_literal: true
require "rails_helper"

RSpec.describe UploadSnapshot, type: :model do
  subject(:upload_snapshot) { described_class.new(filename: filename, url: url, work: work) }

  let(:filename) { "us_covid_2019.csv" }
  let(:url) { "http://localhost.localdomain/us_covid_2019.csv" }
  let(:work) { FactoryBot.create(:approved_work) }

  describe "#filename" do
    it "accesses the filename attribute" do
      expect(upload_snapshot.filename).to eq(filename)
    end
  end

  describe "#url" do
    it "accesses the URL attribute" do
      expect(upload_snapshot.url).to eq(url)
    end
  end

  describe "#uri" do
    let(:uri) { upload_snapshot.uri }

    it "accesses the URI field" do
      expect(uri).to be_a(URI::HTTP)
      expect(uri.to_s).to eq(url)
    end
  end

  describe "#work" do
    it "accesses the Work for which this is a snapshot" do
      expect(upload_snapshot.work).to eq(work)
    end
  end

  describe "#upload" do
    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:work) { FactoryBot.create(:awaiting_approval_work) }
    let(:curator_user) do
      FactoryBot.create(:user, collections_to_admin: [work.collection])
    end

    context "when the Work has not yet been approved" do
      let(:filename) { "#{work.doi}/#{work.id}/us_covid_2019.csv" }
      let(:file1) { FactoryBot.build(:s3_file, filename: filename, work: work, size: 1024) }
      let(:url) { file1.url }

      let(:pre_curation_data_profile) { { objects: [file1] } }
      let(:post_curation_data_profile) { { objects: [] } }

      let(:fake_s3_service_pre) { stub_s3(data: [file1]) }
      let(:fake_s3_service_post) { stub_s3(data: []) }

      before do
        allow(S3QueryService).to receive(:new).and_return(fake_s3_service_pre, fake_s3_service_post)
        allow(fake_s3_service_pre.client).to receive(:head_object).with(bucket: "example-post-bucket", key: work.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
        allow(fake_s3_service_post).to receive(:bucket_name).and_return("example-post-bucket")
        allow(fake_s3_service_pre).to receive(:bucket_name).and_return("example-pre-bucket")

        work.approve!(curator_user)
        work.save
      end

      it "accesses the ActiveStorage attachment for which this is a snapshot" do
        expect(upload_snapshot.upload).not_to be_nil
        expect(upload_snapshot.upload).to eq(file1)
      end
    end

    context "when the Work has been approved" do
      let(:filename) { "#{work.doi}/#{work.id}/us_covid_2019_2.csv" }
      let(:file2) { FactoryBot.build(:s3_file, filename: filename, work: work, size: 2048) }
      let(:url) { file2.url }

      let(:pre_curated_data_profile) { { objects: [file2] } }
      let(:post_curation_data_profile) { { objects: [file2] } }

      let(:fake_s3_service_pre) { stub_s3(data: [file2]) }
      let(:fake_s3_service_post) { stub_s3(data: [file2]) }

      before do
        allow(S3QueryService).to receive(:new).and_return(fake_s3_service_pre, fake_s3_service_post)
        allow(fake_s3_service_pre.client).to receive(:head_object).with(bucket: "example-post-bucket", key: work.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
        allow(fake_s3_service_post).to receive(:bucket_name).and_return("example-post-bucket")
        allow(fake_s3_service_pre).to receive(:bucket_name).and_return("example-pre-bucket")

        work.approve!(curator_user)
        work.save
      end

      it "accesses the ActiveStorage attachment for which this is a snapshot" do
        expect(upload_snapshot.upload).not_to be_nil
        expect(upload_snapshot.upload).to eq(file2)
      end
    end
  end
end
