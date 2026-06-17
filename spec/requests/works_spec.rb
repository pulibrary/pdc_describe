# frozen_string_literal: true
require "rails_helper"

RSpec.describe "/works", type: :request do
  include ActiveJob::TestHelper
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
          allow(stubbed).to receive(:upload_snapshots).and_return([])
          stubbed
        end

        before do
          allow(work).to receive(:id).and_return("test-id")
          allow(work).to receive(:group).and_return(nil)

          allow(Work).to receive(:find).and_return(work)
        end

        it "will raise an error" do
          get work_url(work)
          expect(response).to redirect_to(error_url)
        end
      end

      context "when the Work is under active embargo" do
        let(:embargo_date) { Time.zone.today + 1.year }
        let(:work) do
          FactoryBot.create(:tokamak_work, state: :approved, embargo_date:)
        end

        before do
          stub_ark
        end

        it "will show the work page displaying the work metadata" do
          get work_url(work)

          expect(response.code).to eq "200"
          expect(response.body).to include("Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas")
        end
      end
    end

    context "when the Work is under active embargo" do
      let(:embargo_date) { Time.zone.today + 1.year }
      let(:work) do
        FactoryBot.create(:tokamak_work, state: :approved, embargo_date:)
      end

      before do
        stub_ark
      end

      it "will redirect the client to the authentication page" do
        get work_url(work)

        expect(response.code).to eq "302"
        redirect_location = response.header["Location"]
        expect(redirect_location).to eq "http://www.example.com/sign_in"
      end
    end

    context "when the Work is under an expired embargo" do
      let(:embargo_date) { Time.zone.today - 1.year }
      let(:work) do
        FactoryBot.create(:tokamak_work, state: :approved, embargo_date:)
      end

      before do
        stub_ark
        stub_s3
      end

      it "will show the work page displaying the work metadata" do
        get work_url(work), params: { format: :json }

        expect(response.code).to eq "200"
        expect(response.body).to include("Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas")
      end
    end
  end

  describe "POST /work" do
    let(:group) { Group.plasma_laboratory }
    let(:work) do
      FactoryBot.create(:tokamak_work, group:, created_by_user_id: user.id, state: "draft")
    end

    context "when authenticated" do
      before do
        sign_in(user)
        stub_s3
      end

      context "when files are added to the Work" do
        let(:work) { FactoryBot.create(:tokamak_work, group:, created_by_user_id: user.id, state: "draft") }

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
            work: { "pre_curation_uploads_added" => uploaded_files }
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

          stub_ark
          patch work_url(work), params: params
          work.reload
        end

        it "renders messages generated for the added files" do
          get work_url(work)

          expect(response.code).to eq "200"
          background_snapshot = BackgroundUploadSnapshot.last
          expect(background_snapshot.work).to eq(work)
          expect(background_snapshot.files.map { |file| file["user_id"] }.uniq).to eq([user.id])
          expect(background_snapshot.files.first["filename"]).to eq "10.34770/123-abc/1/us_covid_2019.csv"
          expect(background_snapshot.files.first["upload_status"]).to eq "complete"
          expect(background_snapshot.files.second["filename"]).to eq "10.34770/123-abc/1/us_covid_2020.csv"
          expect(background_snapshot.files.second["upload_status"]).to eq "complete"
        end
      end

      context "when the files are updated before viewing the Work", js: true do
        let(:work) { FactoryBot.create(:tokamak_work, group:, created_by_user_id: user.id, state: "draft") }

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
        let(:file1) { FactoryBot.build :s3_file, work:, filename: uploaded_file1.path, checksum: "222333", last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
        let(:file_before) { FactoryBot.build :s3_file, work:, filename: uploaded_file1.path, checksum: "1111", last_modified: Time.parse("2022-04-21T19:29:40.000Z") }

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
          expect { get work_url(work) }.to have_enqueued_job(UpdateSnapshotJob)

          # Job gets queued so the changes are not present
          expect(response.code).to eq "200"
          expect(response.body).not_to include("Files Replaced: 1")

          perform_enqueued_jobs

          # a second get will show the updates that occured
          get work_url(work)

          expect(response.code).to eq "200"
          expect(response.body).to include("Files Replaced: 1")
        end
      end

      context "when an embargo date is specified" do
        let(:embargo_date_param) { "2023-09-06" }
        let(:params) do
          {
            "title_main" => "test dataset updated",
            "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
            "embargo-date" => embargo_date_param
          }
        end
        let(:embargo_date) { Date.parse(embargo_date_param) }

        before do
          stub_ark
        end

        it "updates the embargo date" do
          patch work_url(work), params: params
          work.reload

          expect(work.embargo_date).not_to be nil
          expect(work.embargo_date).to eq(embargo_date)
        end

        context "when an invalid embargo date is specified" do
          let(:embargo_date_param) { "invalid" }

          before do
            allow(Rails.logger).to receive(:error)
          end

          it "sets the embargo date to nil and logs an error" do
            patch work_url(work), params: params
            work.reload

            expect(work.embargo_date).to be nil
            expect(Rails.logger).to have_received(:error).with("Failed to parse the embargo date invalid for Work #{work.id}").at_least(:once)
          end
        end
      end
    end
  end

  describe "POST /work/:id/approve" do
    let(:group) { Group.plasma_laboratory }
    let(:work) do
      FactoryBot.create(:tokamak_work, group:, created_by_user_id: user.id, state:)
    end

    context "when authenticated" do
      before do
        sign_in(user)
        stub_ark
        post approve_work_url(work)
        stub_s3
      end

      context "when an invalid state if specified" do
        let(:state) { "draft" }
        it "flashes the error and redirects the client to the edit view" do
          expect(response.status).to eq(302)
          expect(response.code).to redirect_to("http://www.example.com/works/#{work.id}/edit")
          follow_redirect!

          expect(response.status).to eq(200)
          # rubocop:disable Layout/LineLength
          error_message = "We apologize, the following errors were encountered: Event 'approve' cannot transition from 'draft'. Please contact the PDC Describe administrators for any assistance."
          # rubocop:enable Layout/LineLength
          expect(response.body).to include(error_message)
        end
      end

      context "when the Work has no files attached" do
        let(:state) { "draft" }
        let(:work) do
          FactoryBot.create(:tokamak_work, group:, created_by_user_id: user.id, state:)
        end

        it "flashes the error and redirects the client to the edit view" do
          expect(response.status).to eq(302)
          expect(response.code).to redirect_to("http://www.example.com/works/#{work.id}/edit")
          follow_redirect!

          expect(response.status).to eq(200)
          # rubocop:disable Layout/LineLength
          error_message = "We apologize, the following errors were encountered: Event 'approve' cannot transition from 'draft'. Please contact the PDC Describe administrators for any assistance."
          # rubocop:enable Layout/LineLength
          expect(response.body).to include(error_message)
        end
      end
    end
  end
end
