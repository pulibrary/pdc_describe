# frozen_string_literal: true
require "rails_helper"

RSpec.describe UploadSnapshot, type: :model do
  subject(:upload_snapshot) { described_class.new(uri: uri, work: work) }

  let(:uri) { "/works/1/download?filename=10.34770%2F123-abc%2F1%2Fus_covid_2019.csv" }
  let(:work) { FactoryBot.create(:approved_work) }

  describe "#uri" do
    it "accesses the URI field" do
      expect(upload_snapshot.uri).to eq(uri)
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
      FactoryBot.create(:user, groups_to_admin: [work.group])
    end

    context "when the Work has not yet been approved" do
      let(:file1) { FactoryBot.build(:s3_file, filename: "#{work.doi}/#{work.id}/us_covid_2019.csv", work: work, size: 1024) }
      let(:uri) { file1.url }

      let(:pre_curation_data_profile) { { objects: [file1] } }
      let(:post_curation_data_profile) { { objects: [] } }

      let(:fake_s3_service_pre) { stub_s3(data: [file1]) }
      let(:fake_s3_service_post) { stub_s3(data: []) }

      before do
        allow(S3QueryService).to receive(:new).and_return(fake_s3_service_pre, fake_s3_service_post)
        allow(fake_s3_service_pre.client).to receive(:head_object).with(bucket: "example-post-bucket", key: work.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
        allow(fake_s3_service_post).to receive(:bucket_name).and_return("example-post-bucket")
        allow(fake_s3_service_pre).to receive(:bucket_name).and_return("example-pre-bucket")
        stub_ark
        stub_datacite_doi

        work.approve!(curator_user)
        work.save
      end

      it "accesses the ActiveStorage attachment for which this is a snapshot" do
        expect(upload_snapshot.upload).not_to be_nil
        expect(upload_snapshot.upload).to eq(file1)
      end
    end

    context "when the Work has been approved" do
      let(:file2) { FactoryBot.build(:s3_file, filename: "#{work.doi}/#{work.id}/us_covid_2019_2.csv", work: work, size: 2048) }
      let(:uri) { file2.url }

      let(:pre_curated_data_profile) { { objects: [file2] } }
      let(:post_curation_data_profile) { { objects: [file2] } }

      let(:fake_s3_service_pre) { stub_s3(data: [file2]) }
      let(:fake_s3_service_post) { stub_s3(data: [file2]) }

      before do
        allow(S3QueryService).to receive(:new).and_return(fake_s3_service_pre, fake_s3_service_post)
        allow(fake_s3_service_pre.client).to receive(:head_object).with(bucket: "example-post-bucket", key: work.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
        allow(fake_s3_service_post).to receive(:bucket_name).and_return("example-post-bucket")
        allow(fake_s3_service_pre).to receive(:bucket_name).and_return("example-pre-bucket")
        stub_ark
        stub_datacite_doi

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
