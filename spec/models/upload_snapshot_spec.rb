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
      FactoryBot.create(:user, groups_to_admin: [work.group])
    end
    let(:s3_query_service1) { instance_double(S3QueryService) }
    let(:s3_query_service2) { instance_double(S3QueryService) }

    before(:all) do
      RSpec::Mocks.with_temporary_scope do
        work = FactoryBot.create(:approved_work)
        filename = "#{work.doi}/#{work.id}/us_covid_2019.csv"
        file1 = FactoryBot.build(:s3_file, filename: filename, work: work, size: 1024)
        s3_query_service1 = instance_double(S3QueryService)
        s3_query_service2 = instance_double(S3QueryService)

        allow(s3_query_service2).to receive(:client_s3_files).and_return([])
        allow(s3_query_service1).to receive(:client_s3_files).and_return([file1])
        allow(s3_query_service2).to receive(:bucket_name).and_return("example-post-bucket")
        allow(s3_query_service1).to receive(:bucket_name).and_return("example-pre-bucket")
      end
    end

    context "when the Work has not yet been approved", mock_s3_query_service_class: false do
      it "accesses the file upload for which this is a snapshot" do
        s3_query_service1 = instance_double(S3QueryService)
        s3_query_service2 = instance_double(S3QueryService)
        filename2 = "us_covid_2019.csv"
        file2 = FactoryBot.build(:s3_file, filename: filename2, size: 1024)

        allow(s3_query_service2).to receive(:client_s3_files).and_return([])
        allow(s3_query_service1).to receive(:client_s3_files).and_return([file2])
        allow(s3_query_service2).to receive(:bucket_name).and_return("example-post-bucket")
        allow(s3_query_service1).to receive(:bucket_name).and_return("example-pre-bucket")

        allow(S3QueryService).to receive(:new).and_return(s3_query_service1)
        work2 = FactoryBot.create(:awaiting_approval_work)
        stub_ark
        stub_datacite_doi

        upload_snapshot = described_class.new(files: [{ filename: filename2, checkSum: "aaabbb111222" }], url: file2.url, work: work2)

        expect(upload_snapshot.upload).not_to be_nil
        expect(upload_snapshot.upload).to eq(file2)
      end
    end

    context "when the Work has been approved", mock_s3_query_service_class: false do
      before do
        stub_datacite_doi
      end

      it "accesses the ActiveStorage attachment for which this is a snapshot" do
        s3_query_service1 = instance_double(S3QueryService)
        s3_query_service2 = instance_double(S3QueryService)

        s3_client = instance_double(Aws::S3::Client)
        allow(s3_client).to receive(:delete_object)
        allow(s3_client).to receive(:put_object)

        filename2 = "us_covid_2019.csv"
        file2 = FactoryBot.build(:s3_file, filename: filename2, size: 1024)

        allow(s3_query_service2).to receive(:client_s3_files).and_return([])
        allow(s3_query_service2).to receive(:bucket_name).and_return("example-post-bucket")

        allow(s3_query_service1).to receive(:client_s3_files).and_return([file2])
        allow(s3_query_service1).to receive(:bucket_name).and_return("example-pre-bucket")
        allow(s3_query_service1).to receive(:data_profile).and_return({ objects: [file2] })
        allow(s3_query_service1).to receive(:publish_files)
        allow(s3_query_service1).to receive(:client).and_return(s3_client)

        allow(S3QueryService).to receive(:new).and_return(s3_query_service1)
        work2 = FactoryBot.create(:awaiting_approval_work)
        allow(s3_client).to receive(:head_object).with(bucket: "example-pre-bucket", key: work2.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))

        work2.approve!(curator_user)
        stub_ark
        stub_datacite_doi

        upload_snapshot = described_class.new(files: [{ filename: filename2, checkSum: "aaabbb111222" }], url: file2.url, work: work2)

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
