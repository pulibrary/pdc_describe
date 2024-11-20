# frozen_string_literal: true
require "rails_helper"

RSpec.describe UploadSnapshot, type: :model do
  subject(:upload_snapshot) { described_class.new(files: [{ filename:, checksum: "aaabbb111222" }], url:, work:) }

  let(:filename) { "us_covid_2019.csv" }
  let(:url) { "http://localhost.localdomain/us_covid_2019.csv" }
  let(:work) { FactoryBot.create(:approved_work) }

  describe "#files" do
    it "lists files associated with the snapshot" do
      expect(upload_snapshot.files).to eq([{ "filename" => filename, "checksum" => "aaabbb111222" }])
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
      FactoryBot.create(:user, groups_to_admin: [work.group])
    end

    context "when the Work has not yet been approved" do
      let(:filename) { "#{work.doi}/#{work.id}/us_covid_2019.csv" }
      let(:file1) { FactoryBot.build(:s3_file, filename:, work:, size: 1024) }
      let(:url) { file1.url }

      let(:pre_curation_data_profile) { { objects: [file1] } }
      let(:post_curation_data_profile) { { objects: [] } }

      let(:fake_s3_service_pre) { stub_s3(data: [file1]) }
      let(:fake_s3_service_post) { stub_s3(data: []) }
      let(:readme) { FactoryBot.build(:s3_readme) }

      before do
        fake_s3_service_post
        fake_s3_service_pre

        allow(S3QueryService).to receive(:new).with(instance_of(Work), "precuration").and_return(fake_s3_service_pre)
        allow(S3QueryService).to receive(:new).with(instance_of(Work), "postcuration").and_return(fake_s3_service_post)
        allow(fake_s3_service_pre.client).to receive(:head_object).with({ bucket: "example-post-bucket", key: work.s3_object_key }).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
        allow(fake_s3_service_post).to receive(:bucket_name).and_return("example-post-bucket")
        allow(fake_s3_service_pre).to receive(:bucket_name).and_return("example-pre-bucket")
        allow(fake_s3_service_pre).to receive(:client_s3_files).and_return([readme], [readme, file1])
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
      let(:file2) { FactoryBot.build(:s3_file, filename:, work:, size: 2048) }
      let(:url) { file2.url }

      let(:pre_curated_data_profile) { { objects: [file2] } }
      let(:post_curation_data_profile) { { objects: [file2] } }

      let(:fake_s3_service_pre) { stub_s3(data: [file2]) }
      let(:fake_s3_service_post) { stub_s3(data: [file2]) }
      let(:readme) { FactoryBot.build(:s3_readme) }

      before do
        fake_s3_service_post
        fake_s3_service_pre

        allow(S3QueryService).to receive(:new).with(instance_of(Work), "precuration").and_return(fake_s3_service_pre)
        allow(S3QueryService).to receive(:new).with(instance_of(Work), "postcuration").and_return(fake_s3_service_post)
        allow(fake_s3_service_pre.client).to receive(:head_object).with({ bucket: "example-post-bucket", key: work.s3_object_key }).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
        allow(fake_s3_service_post).to receive(:bucket_name).and_return("example-post-bucket")
        allow(fake_s3_service_pre).to receive(:bucket_name).and_return("example-pre-bucket")
        allow(fake_s3_service_pre).to receive(:client_s3_files).and_return([readme], [readme, file2])
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

  describe "#snapshot_deletions" do
    it "detects deletions" do
      work_changes = []
      upload_snapshot.snapshot_deletions(work_changes, ["us_covid_other.csv"])
      expect(work_changes.first[:action]).to eq "removed"
      expect(work_changes.first[:filename]).to eq "us_covid_2019.csv"
    end

    it "does not detect false positives" do
      work_changes = []
      upload_snapshot.snapshot_deletions(work_changes, ["us_covid_2019.csv"])
      expect(work_changes.count).to be 0
    end
  end

  describe "#snapshot_modifications" do
    let(:existing_file) { FactoryBot.build :s3_file, filename: "us_covid_2019.csv", checksum: "aaabbb111222" }
    let(:s3_new_file) { FactoryBot.build :s3_file, filename: "one.txt", checksum: "111" }
    let(:s3_modified_file) { FactoryBot.build :s3_file, filename: "us_covid_2019.csv", checksum: "zzzyyyy999888" }
    it "detects additions and modifications" do
      work_changes = []
      upload_snapshot.snapshot_modifications(work_changes, [existing_file, s3_new_file, s3_modified_file])
      expect(work_changes.find { |change| change[:action] == "added" && change[:filename] == "one.txt" }).to_not be nil
      expect(work_changes.find { |change| change[:action] == "replaced" && change[:filename] == "us_covid_2019.csv" }).to_not be nil
    end

    it "does not detect false positives" do
      work_changes = []
      upload_snapshot.snapshot_modifications(work_changes, [existing_file])
      expect(work_changes.count).to be 0
    end
  end

  describe "#compare_checksum" do
    let(:checksum1) { "98691a716ece23a77735f37b5a421253" }
    let(:checksum1_encoded) { "mGkacW7OI6d3NfN7WkISUw==" }
    let(:checksum2) { "xx691a716ece23a77735f37b5a421253" }

    it "matches identical checksums" do
      expect(described_class.checksum_compare(checksum1, checksum1)).to be true
    end

    it "detects differences" do
      expect(described_class.checksum_compare(checksum1, checksum2)).to be false
    end

    it "matches encoded checksums" do
      expect(described_class.checksum_compare(checksum1, checksum1_encoded)).to be true
    end

    it "does not cause issues when the checksum is nil" do
      expect(described_class.checksum_compare(nil, checksum1)).to be false
      expect(described_class.checksum_compare(checksum1, nil)).to be false
    end

    it "return false if the encoding is wrong" do
      expect(described_class.checksum_compare(checksum1, checksum1_encoded + "xxx")).to be false
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
      described_class.new(files: [{ filename: "fileone", checksum: "aaabbb111222" }, { filename: "filetwo", checksum: "aaabbb111222" }], url:, work:)
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
