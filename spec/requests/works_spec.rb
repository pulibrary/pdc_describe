# frozen_string_literal: true
require "rails_helper"

RSpec.describe "/works", type: :request do
  let(:user) { FactoryBot.create :user }

  describe "GET /work" do
    let(:work) do
      FactoryBot.create(:tokamak_work)
    end

    it "will not show a work page unless the user is logged in" do
      get work_url(work)
      expect(response.code).to eq "302"
      redirect_location = response.header["Location"]
      expect(redirect_location).to eq "http://www.example.com/sign_in"
    end

    context "when authenticated" do
      before do
        sign_in(user)
        stub_s3
      end

      it "will show the work page displaying the work metadata" do
        get work_url(work)

        expect(response.code).to eq "200"
        expect(response.body).to include("Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas")
      end

      context "when the work does not have a valid group" do
        let(:work) do
          stubbed = instance_double(Work)
          allow(stubbed).to receive(:s3_object_key).and_return("test-key")
          allow(stubbed).to receive(:reload_snapshots)
          stubbed_resource = instance_double(PDCMetadata::Resource)
          allow(stubbed).to receive(:resource).and_return(stubbed_resource)
          stubbed
        end

        before do
          allow(work).to receive(:id).and_return("test-id")
          allow(work).to receive(:group).and_return(nil)

          allow(Work).to receive(:find).and_return(work)
        end

        it "will raise an error" do
          expect { get work_url(work) }.to raise_error(Work::InvalidGroupError, "The Work test-id does not belong to any Group")
        end
      end
    end
  end

  describe "POST /work" do
    let(:group) { Group.plasma_laboratory }
    let(:work) do
      FactoryBot.create(:tokamak_work, group: group, created_by_user_id: user.id, state: "draft")
    end

    context "when authenticated" do
      before do
        sign_in(user)
        stub_s3
      end

      context "when files are added to the Work" do
        let(:work) { FactoryBot.create(:tokamak_work, group: group, created_by_user_id: user.id, state: "draft") }

        let(:uploaded_file1) do
          fixture_file_upload("us_covid_2019.csv", "text/csv")
        end

        let(:uploaded_file2) do
          fixture_file_upload("us_covid_2020.csv", "text/csv")
        end

        let(:uploaded_files) do
          [
            uploaded_file1,
            uploaded_file2
          ]
        end

        let(:params) do
          {
            "title_main" => "test dataset updated",
            "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
            "pre_curation_uploads_added" => uploaded_files
          }
        end

        let(:bucket_url) do
          "https://example-bucket.s3.amazonaws.com/"
        end

        let(:fake_s3_service) { stub_s3 }
        let(:file1) { FactoryBot.build :s3_file, filename: uploaded_file1.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z"), checksum: "test1" }
        let(:file2) { FactoryBot.build :s3_file, filename: uploaded_file2.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z"), checksum: "test2" }

        before do
          # This is utilized for active record to send the file to S3
          stub_request(:put, /#{bucket_url}/).to_return(status: 200)
          allow(fake_s3_service).to receive(:client_s3_files).and_return([], [file1, file2])
          allow(AttachFileToWorkJob).to receive(:perform_later)

          stub_ark
          patch work_url(work), params: params
          work.reload
        end

        it "renders messages generated for the added files" do
          get work_url(work)

          expect(response.code).to eq "200"
          expect(AttachFileToWorkJob).to have_received(:perform_later).with(
            user_id: user.id,
            work_id: work.id,
            size: 92,
            file_name: "us_covid_2019.csv",
            file_path: anything
          )
          expect(AttachFileToWorkJob).to have_received(:perform_later).with(
            user_id: user.id,
            work_id: work.id,
            size: 114,
            file_name: "us_covid_2020.csv",
            file_path: anything
          )
        end
      end

      context "when the files are updated before viewing the Work", js: true do
        let(:work) { FactoryBot.create(:tokamak_work, group: group, created_by_user_id: user.id, state: "draft") }

        let(:uploaded_file1) do
          fixture_file_upload("us_covid_2019.csv", "text/csv")
        end

        let(:uploaded_file2) do
          fixture_file_upload("versions/us_covid_2019.csv", "text/csv")
        end

        let(:uploaded_files) do
          [
            uploaded_file2
          ]
        end

        let(:params) do
          {
            "title_main" => "test dataset updated",
            "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
            "pre_curation_uploads_added" => uploaded_files
          }
        end

        let(:bucket_url) do
          "https://example-bucket.s3.amazonaws.com/"
        end

        let(:fake_s3_service) { stub_s3 }
        let(:file1) { FactoryBot.build :s3_file, work: work, filename: uploaded_file1.path, checksum: "222333", last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
        let(:file_before) { FactoryBot.build :s3_file, work: work, filename: uploaded_file1.path, checksum: "1111", last_modified: Time.parse("2022-04-21T19:29:40.000Z") }

        before do
          stub_ark
          # This is utilized for active record to send the file to S3
          stub_request(:put, /#{bucket_url}/).to_return(status: 200)
          allow(fake_s3_service).to receive(:client_s3_files).and_return([file_before], [file1])
          work.save
          work.reload_snapshots
          work.reload

          patch work_url(work), params: params
          work.reload
        end

        it "renders messages generated for the replaced files" do
          get work_url(work)

          expect(response.code).to eq "200"
          expect(response.body).to include("Files Replaced: 1")
        end
      end
    end
  end
end
