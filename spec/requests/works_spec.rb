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

      context "when the work does not have a valid collection" do
        let(:work) do
          stubbed = instance_double(Work)
          allow(stubbed).to receive(:s3_object_key).and_return("test-key")
          stubbed
        end

        before do
          allow(work).to receive(:id).and_return("test-id")
          allow(work).to receive(:collection).and_return(nil)

          allow(Work).to receive(:find).and_return(work)
        end

        it "will raise an error" do
          expect { get work_url(work) }.to raise_error(Work::InvalidCollectionError, "The Work test-id does not belong to any Collection")
        end
      end
    end
  end

  describe "POST /work" do
    let(:collection) { Collection.plasma_laboratory }
    let(:work) do
      FactoryBot.create(:tokamak_work, collection: collection, created_by_user_id: user.id, state: "draft")
    end

    context "when authenticated" do
      before do
        sign_in(user)
        stub_s3
      end

      context "when files are added to the Work" do
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
            "given_name_1" => "Jane",
            "family_name_1" => "Smith",
            "creator_count" => "1",
            "pre_curation_uploads_added" => uploaded_files
          }
        end

        let(:bucket_url) do
          "https://example-bucket.s3.amazonaws.com/"
        end

        let(:fake_s3_service) { stub_s3 }
        let(:file1) { FactoryBot.build :s3_file, filename: uploaded_file1.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
        let(:file2) { FactoryBot.build :s3_file, filename: uploaded_file2.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z") }

        before do
          # This is utilized for active record to send the file to S3
          stub_request(:put, /#{bucket_url}/).to_return(status: 200)
          allow(fake_s3_service).to receive(:client_s3_files).and_return([], [file1, file2])

          patch work_url(work), params: params
          work.reload
        end

        it "renders messages generated for the added files" do
          get work_url(work)

          expect(response.code).to eq "200"
          expect(response.body).to include("Files Added: 2")
        end
      end

      context "when the files are updated before viewing the Work" do
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
            "given_name_1" => "Jane",
            "family_name_1" => "Smith",
            "creator_count" => "1",
            "pre_curation_uploads_added" => uploaded_files
          }
        end

        let(:bucket_url) do
          "https://example-bucket.s3.amazonaws.com/"
        end

        let(:fake_s3_service) { stub_s3 }
        let(:file1) { FactoryBot.build :s3_file, filename: uploaded_file1.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
        let(:file2) { FactoryBot.build :s3_file, filename: uploaded_file2.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z") }

        before do
          # This is utilized for active record to send the file to S3
          stub_request(:put, /#{bucket_url}/).to_return(status: 200)
          allow(fake_s3_service).to receive(:client_s3_files).and_return([], [file1, file2])

          patch work_url(work), params: params
          work.reload
        end

        it "renders messages generated for the replaced files" do
          get work_url(work)

          expect(response.code).to eq "200"
          expect(response.body).to include("Files Added: 2")
        end
      end
    end
  end
end
