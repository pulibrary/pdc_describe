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
                                               filename: "readme_template.txt",
                                               type: "text/plain",
                                               tempfile: File.new(Rails.root.join("spec", "fixtures", "files", "readme_template.txt"))
                                             })
    end
    let(:new_readme) { FactoryBot.build :s3_file, filename: "bucket/key/readme_template.txt" }

    it "attaches the readme file" do
      allow(fake_s3_service).to receive(:client_s3_files).and_return([new_readme])
      allow(fake_s3_service).to receive(:upload_file).with(io: uploaded_file.to_io, filename: "readme_template.txt", size: 2852).and_return("bucket/key/readme_template.txt")
      expect { expect(readme.attach(uploaded_file)).to be_nil }.to change { UploadSnapshot.count }.by 1
      expect(fake_s3_service).to have_received(:upload_file).with(io: uploaded_file.to_io, filename: "readme_template.txt", size: 2852)
      expect(readme.file_name).to eq("readme_template.txt")
      expect(work.activities.first.message).to eq("[{\"action\":\"added\",\"filename\":\"bucket/key/readme_template.txt\",\"checksum\":\"abc123\"}]")
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
        expect(fake_s3_service).to have_received(:upload_file).with(io: uploaded_file.to_io, filename: "readme_template.txt", size: 2852)
      end
    end

    context "there is an existing readme that should be replaced" do
      let(:s3_files) { [FactoryBot.build(:s3_file, work:), FactoryBot.build(:s3_readme, work:)] }
      let(:new_readme) { FactoryBot.build :s3_file, filename: "bucket/key/readme_template.txt" }

      it "returns no error message" do
        allow(fake_s3_service).to receive(:client_s3_files).and_return(s3_files, s3_files, s3_files, [s3_files.first, new_readme])
        allow(fake_s3_service).to receive(:upload_file).with(io: uploaded_file.to_io, filename: "readme_template.txt", size: 2852).and_return("bucket/key/readme_template.txt")
        work.reload_snapshots
        expect { expect(readme.attach(uploaded_file)).to be_nil }.to change { UploadSnapshot.count }.by 1
        expect(fake_s3_service).to have_received(:upload_file).with(io: uploaded_file.to_io, filename: "readme_template.txt", size: 2852)
        expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_files.last.key)
        expect(readme.file_name).to eq("readme_template.txt")
        expect(work.activities.last.message).to eq("[{\"action\":\"removed\",\"filename\":\"README.txt\",\"checksum\":\"abc123\"}," \
                                                   "{\"action\":\"added\",\"filename\":\"bucket/key/readme_template.txt\",\"checksum\":\"abc123\"}]")
      end
    end
  end
end
