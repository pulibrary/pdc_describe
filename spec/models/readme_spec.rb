# frozen_string_literal: true
require "rails_helper"

RSpec.describe Readme, type: :model do
  let(:work) { FactoryBot.create :draft_work }
  let(:s3_files) { [FactoryBot.build(:s3_file, work:), FactoryBot.build(:s3_file, filename: "filename-2.txt", work:)] }
  let(:readme) { described_class.new(work, User.find(work.created_by_user_id)) }
  let(:fake_s3_service) { stub_s3 data: s3_files }

  before do
    fake_s3_service
  end

  describe "#blank?" do
    it "Does not find a readme" do
      expect(readme.blank?).to be_truthy
    end

    context "with a readme present" do
      let(:s3_files) { [FactoryBot.build(:s3_file, work:), FactoryBot.build(:s3_readme, work:)] }
      it "Does not find a readme" do
        expect(readme.blank?).to be_falsey
      end
    end
  end

  describe "#attach" do
    let(:uploaded_file) do
      ActionDispatch::Http::UploadedFile.new({
                                               filename: "orcid.csv",
                                               type: "text/csv",
                                               tempfile: File.new(Rails.root.join("spec", "fixtures", "files", "orcid.csv"))
                                             })
    end

    it "attaches the file and renames to to README" do
      allow(fake_s3_service).to receive(:upload_file).with(io: uploaded_file.to_io, filename: "README.csv", size: 287).and_return("bucket/key/README.csv")
      expect { expect(readme.attach(uploaded_file)).to be_nil }.to change { UploadSnapshot.count }.by 1
      expect(fake_s3_service).to have_received(:upload_file).with(io: uploaded_file.to_io, filename: "README.csv", size: 287)
      expect(readme.file_name).to eq("orcid.csv")
      expect(work.activities.first.message).to eq("[{\"action\":\"added\",\"filename\":\"bucket/key/README.csv\"}]")
    end

    context "when no uploaded file is sent" do
      let(:uploaded_file) { nil }

      it "returns an error message" do
        expect(readme.attach(uploaded_file)).to eq("A README file is required!")
        expect(fake_s3_service).not_to have_received(:upload_file)
      end

      context "when a readme is already present" do
        let(:s3_files) { [FactoryBot.build(:s3_file, work:), FactoryBot.build(:s3_readme, work:)] }

        it "returns no error message" do
          expect { expect(readme.attach(uploaded_file)).to be_nil }.to change { UploadSnapshot.count }.by 0
          expect(fake_s3_service).not_to have_received(:upload_file)
        end
      end
    end

    context "there is an error with the upload" do
      before do
        allow(fake_s3_service).to receive(:upload_file).and_return(false)
      end

      it "returns an error message" do
        expect(readme.attach(uploaded_file)).to eq("An error uploading your README was encountered.  Please try again.")
        expect(fake_s3_service).to have_received(:upload_file).with(io: uploaded_file.to_io, filename: "README.csv", size: 287)
      end
    end

    context "there is an existing readme that should be replaced" do
      let(:s3_files) { [FactoryBot.build(:s3_file, work:), FactoryBot.build(:s3_readme, work:)] }

      it "returns no error message" do
        allow(fake_s3_service).to receive(:upload_file).with(io: uploaded_file.to_io, filename: "README.csv", size: 287).and_return("bucket/key/README.csv")
        expect { expect(readme.attach(uploaded_file)).to be_nil }.to change { UploadSnapshot.count }.by 1
        expect(fake_s3_service).to have_received(:upload_file).with(io: uploaded_file.to_io, filename: "README.csv", size: 287)
        expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_files.last.key)
        expect(readme.file_name).to eq("orcid.csv")
        expect(work.activities.first.message).to eq("[{\"action\":\"removed\",\"filename\":\"README.txt\"},{\"action\":\"added\",\"filename\":\"bucket/key/README.csv\"}]")
      end
    end
  end
end
