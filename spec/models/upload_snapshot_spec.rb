# frozen_string_literal: true
require "rails_helper"

RSpec.describe UploadSnapshot, type: :model do
  subject(:upload_snapshot) { described_class.new(files: [{ filename: filename, checkSum: "aaabbb111222" }], url: url, work: work) }

  let(:filename) { "us_covid_2019.csv" }
  let(:url) { "http://localhost.localdomain/us_covid_2019.csv" }
  let(:work) { FactoryBot.create(:approved_work) }

  describe "#files" do
    it "lists files associated with the snapshot" do
      expect(upload_snapshot.files).to eq([{ "filename" => filename, "checkSum" => "aaabbb111222" }])
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

  describe "#filenames" do
    it "lists filenames associated with the snapshot" do
      expect(upload_snapshot.filenames).to eq([filename])
    end
  end

  describe "#include?" do
    subject(:upload_snapshot) { described_class.new(files: [{ filename: "fileone", checksum: "aaabbb111222" }, { filename: "filetwo", checksum: "aaabbb111222" }], url: url, work: work) }

    let(:s3_file) { FactoryBot.build :s3_file, filename: "fileone" }
    let(:other_file) { FactoryBot.build :s3_file, filename: "other" }
    it "checks if a files is part of the snamshot via name" do
      expect(upload_snapshot.include?(s3_file)).to be_truthy
      expect(upload_snapshot.include?(other_file)).to be_falsey
    end
  end

  describe "#index" do
    subject(:upload_snapshot) { described_class.new(files: [{ filename: "fileone", checksum: "aaabbb111222" }, { filename: "filetwo", checksum: "aaabbb111222" }], url: url, work: work) }

    let(:s3_file) { FactoryBot.build :s3_file, filename: "filetwo", checksum: "aaabbb111222" }
    let(:other_file) { FactoryBot.build :s3_file, filename: "other" }
    subject(:upload_snapshot) { described_class.new(files: [{ filename: "fileone", checksum: "aaabbb111222" }, { filename: "filetwo", checksum: "aaabbb111222" }], url: url, work: work) }

    it "lists filenames associated with the snapshot" do
      expect(upload_snapshot.index(s3_file)).to eq(1)
      expect(upload_snapshot.index(other_file)).to be_nil
    end

    it "checks both the filename and the checksum" do
      s3_file.checksum = "otherchecksum"
      expect(upload_snapshot.index(s3_file)).to be_nil
    end
  end

  describe "#match?" do
    subject(:upload_snapshot) { described_class.new(files: [{ filename: "fileone", checksum: "aaabbb111222" }, { filename: "filetwo", checksum: "aaabbb111222" }], url: url, work: work) }

    let(:s3_file) { FactoryBot.build :s3_file, filename: "filetwo", checksum: "aaabbb111222" }
    let(:other_file) { FactoryBot.build :s3_file, filename: "other" }
    subject(:upload_snapshot) { described_class.new(files: [{ filename: "fileone", checksum: "aaabbb111222" }, { filename: "filetwo", checksum: "aaabbb111222" }], url: url, work: work) }

    it "lists filenames associated with the snapshot" do
      expect(upload_snapshot.match?(s3_file)).to be_truthy
      expect(upload_snapshot.match?(other_file)).to be_falsey
    end

    it "checks both the filename and the checksum" do
      s3_file.checksum = "otherchecksum"
      expect(upload_snapshot.match?(s3_file)).to be_falsey
    end
  end

  describe "#store_files" do
    let(:s3_file1) { FactoryBot.build :s3_file, filename: "fileone", checksum: "aaabbb111222" }
    let(:s3_file2) { FactoryBot.build :s3_file, filename: "filetwo", checksum: "dddeee111222" }
    it "lists filenames associated with the snapshot" do
      upload_snapshot.store_files([s3_file1, s3_file2])
      expect(upload_snapshot.files).to eq([{ "filename" => "fileone", "checksum" => "aaabbb111222" },
                                           { "filename" => "filetwo", "checksum" => "dddeee111222" }])
    end
  end

  describe "#find_by_filename" do
    subject(:upload_snapshot) do
      described_class.new(files: [{ filename: "fileone", checksum: "aaabbb111222" }, { filename: "filetwo", checksum: "aaabbb111222" }], url: url, work: work)
    end

    let(:s3_file) { FactoryBot.build :s3_file, filename: "fileone" }
    let(:other_file) { FactoryBot.build :s3_file, filename: "other" }
    it "checks if a files is part of the snamshot via name" do
      expect(UploadSnapshot.find_by_filename(work_id: work.id, filename: "fileone")).to be_nil
      upload_snapshot.save
      expect(UploadSnapshot.find_by_filename(work_id: work, filename: "fileone")).to eq(upload_snapshot)
      expect(UploadSnapshot.find_by_filename(work_id: work, filename: "filetwo")).to eq(upload_snapshot)
    end
  end
end
