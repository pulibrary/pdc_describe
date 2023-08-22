# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorksController do
  include ActiveJob::TestHelper
  before do
    Group.create_defaults
    user
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original

    stub_request(:get, /#{Regexp.escape("https://example-bucket.s3.amazonaws.com/us_covid_20")}.*\.csv/).to_return(status: 200, body: "", headers: {})
  end

  let(:group) { Group.first }
  let(:curator) { FactoryBot.create(:user, groups_to_admin: [group]) }
  let(:resource) { FactoryBot.build :resource }
  let(:work) { FactoryBot.create(:draft_work, doi: "10.34770/123-abc") }
  let(:user) { work.created_by_user }
  let(:pppl_user) { FactoryBot.create(:pppl_submitter) }

  let(:uploaded_file) { fixture_file_upload("us_covid_2019.csv", "text/csv") }

  context "valid user login" do
    it "handles the index page" do
      sign_in user
      get :index
      expect(response).to render_template("index")
    end

    it "has an rss feed" do
      sign_in user
      get :index, format: "rss"
      expect(response.content_type).to eq "application/rss+xml; charset=utf-8"
    end

    it "renders the work json" do
      sign_in user
      stub_s3
      get :show, params: { id: work.id, format: "json" }
      expect(response.content_type).to eq "application/json; charset=utf-8"
      work_json = JSON.parse(response.body)
      expect(work_json["resource"]).to_not be nil
      expect(work_json["files"]).to_not be nil
      expect(work_json["group"]).to_not be nil
    end

    it "renders the new submission wizard' step 0" do
      sign_in user
      get :new, params: { wizard: true }
      expect(response).to render_template("new_submission")
    end

    it "renders the new form" do
      sign_in user
      get :new
      expect(response).to render_template("new")
    end

    it "renders the edit page when creating a new dataset" do
      params = {
        "title_main" => "test dataset updated",
        "group_id" => work.group.id,
        "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
      }
      sign_in user
      post :new_submission, params: params
      expect(response.status).to be 302
      expect(response.location.start_with?("http://test.host/works/")).to be true
    end

    # In theory we should never get to the new submission without a title, because the javascript should prevent it
    # In reality we are occasionally having issues with the javascript failing and the button submitting anyway.
    it "renders the edit page when creating a new dataset without a title" do
      params = {
        "group_id" => work.group.id,
        "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
      }
      sign_in user
      post :new_submission, params: params
      expect(response.status).to be 422
      expect(assigns[:errors]).to eq(["Cannot Draft: Must provide a title"])
      expect(response).to render_template :new_submission
    end

    it "handles the update page" do
      params = {
        "title_main" => "test dataset updated",
        "description" => "a new description",
        "group_id" => work.group.id,
        "commit" => "Update Dataset",
        "controller" => "works",
        "action" => "update",
        "id" => work.id.to_s,
        "publisher" => "Princeton University",
        "publication_year" => "2022",
        "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
        "resource_type" => "Dataset",
        "resource_type_general" => "Dataset"
      }
      sign_in user
      post :update, params: params
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"

      work.reload
      expect(work.resource_type).to eq("Dataset")
      expect(work.resource_type_general).to eq("Dataset")
      expect(ActiveStorage::PurgeJob).not_to have_received(:new)
    end

    context "when the client uses wizard mode" do
      it "updates the Work and redirects the client to select attachments" do
        params = {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "Update Dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "wizard" => "true",
          "publisher" => "Princeton University",
          "publication_year" => "2022",
          creators: [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
        }
        sign_in user
        post :update, params: params
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}/readme-select"
        expect(ActiveStorage::PurgeJob).not_to have_received(:new)
      end
    end

    it "handles the reordering the creators on the update page" do
      params = {
        "doi" => "10.34770/tbd",
        "title_main" => "test dataset updated",
        "description" => "a new description",
        "group_id" => work.group.id,
        "commit" => "Update Dataset",
        "controller" => "works",
        "action" => "update",
        "id" => work.id.to_s,
        "publisher" => "Princeton University",
        "publication_year" => "2022",
        creators: [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" },
                   { "orcid" => "", "given_name" => "Ada", "family_name" => "Lovelace" }],
        "resource_type" => "Dataset",
        "resource_type_general" => "Dataset"
      }
      sign_in user
      post :update, params: params

      saved_work = Work.find(work.id)

      # Test that author order is preserved in the Resource
      expect(saved_work.resource.creators[0].value).to eq "Smith, Jane"
      expect(saved_work.resource.creators[1].value).to eq "Lovelace, Ada"

      # Test that author order is preserved in the DataCite XML Serialization
      datacite_xml = saved_work.to_xml
      datacite_nokogiri = Nokogiri::XML(datacite_xml)
      datacite_creators = datacite_nokogiri.xpath("/xmlns:resource/xmlns:creators/xmlns:creator/xmlns:creatorName/text()")
      expect(datacite_creators.size).to eq 2
      expect(datacite_creators.first.text).to eq "Smith, Jane"
      expect(datacite_creators.last.text).to eq "Lovelace, Ada"

      params_reordered = {
        "doi" => "10.34770/tbd",
        "title_main" => "test dataset with reordered authors",
        "description" => "a new description",
        "group_id" => work.group.id,
        "commit" => "Update Dataset",
        "controller" => "works",
        "action" => "update",
        "id" => work.id.to_s,
        "publisher" => "Princeton University",
        "publication_year" => "2022",
        creators: [{ "orcid" => "", "given_name" => "Ada", "family_name" => "Lovelace" },
                   { "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
        "resource_type" => "Dataset",
        "resource_type_general" => "Dataset"
      }

      post :update, params: params_reordered
      reordered_work = Work.find(work.id)

      # Test that author order is preserved in the Resource
      expect(reordered_work.resource.creators[0].value).to eq "Lovelace, Ada"
      expect(reordered_work.resource.creators[1].value).to eq "Smith, Jane"

      # Test that author order is preserved in the DataCite XML Serialization
      datacite_xml = reordered_work.to_xml
      datacite_nokogiri = Nokogiri::XML(datacite_xml)
      datacite_creators = datacite_nokogiri.xpath("/xmlns:resource/xmlns:creators/xmlns:creator/xmlns:creatorName/text()")
      expect(datacite_creators.size).to eq 2
      expect(datacite_creators.first.text).to eq "Lovelace, Ada"
      expect(datacite_creators.last.text).to eq "Smith, Jane"
    end

    context "with new file uploads for an existing Work without uploads" do
      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      let(:file1) { FactoryBot.build :s3_file, filename: "anyfile.txt", last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
      let(:fake_s3_service) { stub_s3 }

      before do
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
        allow(fake_s3_service).to receive(:client_s3_files).and_return([file1])
        allow(AttachFileToWorkJob).to receive(:perform_later)
      end

      it "handles the update page" do
        params = {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          creators: [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" },
                     { "orcid" => "", "given_name" => "Ada", "family_name" => "Lovelace" }],
          work: { "pre_curation_uploads_added" => uploaded_file }
        }
        sign_in user
        post :update, params: params

        saved_work = Work.find(work.id)

        expect(saved_work.pre_curation_uploads_fast).not_to be_empty
        expect(fake_s3_service).not_to have_received(:delete_s3_object)
        background_snapshot = BackgroundUploadSnapshot.last
        expect(background_snapshot.work).to eq(work)
        expect(background_snapshot.files.map { |file| file["user_id"] }.uniq).to eq([user.id])
        expect(AttachFileToWorkJob).to have_received(:perform_later).with(
          background_upload_snapshot_id: background_snapshot.id,
          size: 92,
          file_name: "us_covid_2019.csv",
          file_path: anything
        )
      end
    end

    context "when all file uploads are replaced for an existing Work with uploads" do
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

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      let(:fake_s3_service) { stub_s3 }
      let(:file1) { FactoryBot.build :s3_file, filename: uploaded_file1.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
      let(:file2) { FactoryBot.build :s3_file, filename: uploaded_file2.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z") }

      before do
        # This is utilized for active record to send the file to S3
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
        allow(fake_s3_service).to receive(:client_s3_files).and_return([file1, file2])
        allow(AttachFileToWorkJob).to receive(:perform_later)
      end

      it "handles the update page" do
        params = {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" },
                         { "orcid" => "", "given_name" => "Ada", "family_name" => "Lovelace" }],
          work: { "pre_curation_uploads_added" => uploaded_files }
        }
        sign_in user
        post :update, params: params

        saved_work = Work.find(work.id)

        expect(saved_work.pre_curation_uploads_fast).not_to be_empty
        expect(fake_s3_service).not_to have_received(:delete_s3_object)
        background_snapshot = BackgroundUploadSnapshot.last
        expect(background_snapshot.work).to eq(work)
        expect(background_snapshot.files.map { |file| file["user_id"] }.uniq).to eq([user.id])
        expect(AttachFileToWorkJob).to have_received(:perform_later).with(
          background_upload_snapshot_id: background_snapshot.id,
          size: 92,
          file_name: "us_covid_2019.csv",
          file_path: anything
        )
        expect(AttachFileToWorkJob).to have_received(:perform_later).with(
          background_upload_snapshot_id: background_snapshot.id,
          size: 114,
          file_name: "us_covid_2020.csv",
          file_path: anything
        )
      end
    end

    context "when only some file uploads are replaced for an existing Work with uploads" do
      let(:uploaded_file1) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:uploaded_file2) do
        fixture_file_upload("us_covid_2020.csv", "text/csv")
      end

      let(:uploaded_files) { [uploaded_file1, uploaded_file2] }

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      let(:fake_s3_service) { stub_s3 }
      let(:file1) { FactoryBot.build :s3_file, filename: uploaded_file1.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
      let(:file2) { FactoryBot.build :s3_file, filename: uploaded_file2.path, last_modified: Time.parse("2022-04-21T18:29:40.000Z") }

      let(:base_params) do
        {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" },
                         { "orcid" => "", "given_name" => "Ada", "family_name" => "Lovelace" }]
        }
      end

      before do
        # This is utilized for active record to send the file to S3
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
        allow(fake_s3_service).to receive(:client_s3_files).and_return([file1, file2])

        params = base_params.clone
        params[:work] = { pre_curation_uploads_added: [uploaded_file1, uploaded_file2] }
        sign_in user
        post :update, params: params
      end

      it "handles the update page" do
        expect(work.pre_curation_uploads_fast.count).to eq 2

        params = base_params.clone
        params[:work] = { pre_curation_uploads_added: [uploaded_file2],
                          deleted_files_count: "1",
                          deleted_file_1: uploaded_file2.original_filename }
        post :update, params: params

        saved_work = Work.find(work.id)
        expect(saved_work.pre_curation_uploads_fast.count).to eq 2
        expect(fake_s3_service).to have_received(:delete_s3_object).once
      end
    end

    context "when only some file uploads are deleted for an existing Work with uploads" do
      let(:s3_file1) { FactoryBot.build :s3_file, filename: "us_covid_2020.csv", work: work }
      let(:s3_file2) { FactoryBot.build :s3_file, filename: "us_covid_2021.csv", work: work }
      let(:s3_file3) { FactoryBot.build :s3_file, filename: "us_covid_2022.csv", work: work }

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      # Notice that we do NOT pass deleted_files_count on purpose
      let(:params_no_delete) do
        {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" },
                         { "orcid" => "", "given_name" => "Ada", "family_name" => "Lovelace" }],
          "rights_identifiers" => ["CC BY"]
        }.with_indifferent_access
      end
      let(:params) do
        params_no_delete.merge({ "work[deleted_files_count]" => "2",
                                 "work[deleted_file_1]" => s3_file1.key,
                                 "work[deleted_file_2]" => s3_file3.key })
      end

      before do
        stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
      end

      context "when the Work has not been curated" do
        let(:fake_s3_service) { stub_s3 }
        before do
          allow(fake_s3_service).to receive(:client_s3_files).and_return([s3_file1, s3_file2, s3_file3], [s3_file2])
        end

        it "handles the update page" do
          expect(work.pre_curation_uploads_fast.length).to eq(3)

          sign_in user
          post :update, params: params

          saved_work = Work.find(work.id)

          expect(saved_work.pre_curation_uploads_fast.length).to eq(1)

          expect(ActiveStorage::PurgeJob).not_to have_received(:new)
          expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file1.key)
          expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file3.key)
          expect(fake_s3_service).not_to have_received(:delete_s3_object).with(s3_file2.key)
        end
      end

      context "when the Work has been curated" do
        let(:work) { FactoryBot.create(:approved_work) }
        let(:user) do
          FactoryBot.create :user, groups_to_admin: [work.group]
        end
        let(:s3_query_service_double) { instance_double(S3QueryService) }
        let(:file1) { FactoryBot.build :s3_file, filename: "SCoData_combined_v1_2020-07_README.txt", work: work }
        let(:file2) { FactoryBot.build :s3_file, filename: "SCoData_combined_v1_2020-07_datapackage.json", work: work }
        let(:s3_data) { [file1, file2] }
        let(:bucket_url) do
          "https://example-bucket.s3.amazonaws.com/"
        end
        let(:params) do
          params_no_delete.merge({ "work[deleted_files_count]" => "2",
                                   "work[deleted_file_1]" => work.post_curation_uploads.first.key,
                                   "work[deleted_file_2]" => work.post_curation_uploads.last.key })
        end

        let(:s3_client) { instance_double(Aws::S3::Client) }
        let(:s3_object) { double }
        let(:uploaded_file) { fixture_file_upload("us_covid_2019.csv", "text/csv") }

        before do
          # Account for files in S3 added outside of ActiveStorage
          allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
          allow(s3_query_service_double).to receive(:bucket_name).and_return("example-bucket")
          allow(s3_client).to receive(:delete_object)
          allow(s3_client).to receive(:put_object)
          allow(s3_client).to receive(:head_object).with(bucket: "example-bucket", key: "#{work.s3_object_key}/us_covid_2019.csv").and_return(true)
          allow(s3_client).to receive(:head_object).with(bucket: "example-bucket", key: work.s3_object_key.to_s)
          allow(s3_query_service_double).to receive(:client).and_return(s3_client)
          allow(s3_query_service_double).to receive(:data_profile).and_return({ objects: s3_data, ok: true })

          stub_request(:put, "https://api.datacite.org/dois/#{work.doi}").to_return(status: 200, body: "", headers: {})

          sign_in user
        end

        it "returns with a 403 response code" do
          expect(work.post_curation_uploads.length).to eq(2)

          sign_in user
          post :update, params: params

          expect(response).to have_http_status(:forbidden)
        end

        it "saves OK if no deletes where indicated" do
          allow(controller).to receive(:params).and_return(params_no_delete)
          expect(work.post_curation_uploads.length).to eq(2)

          sign_in user
          post :update, params: params_no_delete

          expect(response).to redirect_to(work_path(work))
          expect(ActiveStorage::PurgeJob).not_to have_received(:new)
        end
      end
    end

    context "when creating a work without the wizard" do
      let(:uploaded_file1) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:file1) { FactoryBot.build :s3_file, filename: uploaded_file1.path, work: work }

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      let(:request_params) do
        {
          "title_main" => "a new title #{rand(10_000)}",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
          work: { "pre_curation_uploads_added" => [uploaded_file1] }
        }
      end
      let(:fake_s3_service) { stub_s3(data: [file1]) }

      before do
        fake_s3_service
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
        sign_in user
      end

      it "files are saved" do
        post :create, params: request_params
        perform_enqueued_jobs
        expect(fake_s3_service).to have_received(:upload_file).with(hash_including(filename: "us_covid_2019.csv"))
      end
    end

    context "when file uploads are present for an existing Work with uploads" do
      let(:uploaded_file1) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:uploaded_file2) do
        fixture_file_upload("us_covid_2020.csv", "text/csv")
      end

      let(:uploaded_files) do
        [
          uploaded_file2,
          uploaded_file1
        ]
      end

      let(:file1) { FactoryBot.build :s3_file, filename: uploaded_file1.path, work: work }
      let(:file2) { FactoryBot.build :s3_file, filename: uploaded_file2.path, work: work }

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      let(:request_params) do
        {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" },
                         { "orcid" => "", "given_name" => "Ada", "family_name" => "Lovelace" }],
          work: {
            "pre_curation_uploads_added" => uploaded_files,
            "deleted_files_count" => "2",
            "deleted_file_1" => uploaded_file1.original_filename,
            "deleted_file_2" => uploaded_file2.original_filename
          }
        }
      end
      let(:fake_s3_service) { stub_s3(data: [file1, file2]) }

      before do
        fake_s3_service
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
        stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
        allow(AttachFileToWorkJob).to receive(:perform_later)

        sign_in user
      end

      it "handles the update page" do
        post :update, params: request_params

        saved_work = Work.find(work.id)

        expect(saved_work.pre_curation_uploads_fast).not_to be_empty

        # order is alphabetical, we can not change it by sending the files in a different order
        expect(saved_work.pre_curation_uploads_fast.first.filename).to include(uploaded_files.last.original_filename.gsub(".csv", ""))
        expect(saved_work.pre_curation_uploads_fast.last.filename).to include(uploaded_files.first.original_filename.gsub(".csv", ""))

        # original copies of the files get deleted
        expect(fake_s3_service).to have_received(:delete_s3_object).twice
        background_snapshot = BackgroundUploadSnapshot.last
        expect(background_snapshot.work).to eq(work)
        expect(background_snapshot.files.map { |file| file["user_id"] }.uniq).to eq([user.id])
        expect(AttachFileToWorkJob).to have_received(:perform_later).with(
          background_upload_snapshot_id: background_snapshot.id, size: 114,
          file_name: uploaded_files.first.original_filename, file_path: anything
        )
        expect(AttachFileToWorkJob).to have_received(:perform_later).with(
          background_upload_snapshot_id: background_snapshot.id, size: 92,
          file_name: uploaded_files.last.original_filename, file_path: anything
        )
      end
    end

    describe "#readme_select" do
      let(:fake_readme) { instance_double Readme, file_name: "README.txt" }

      before do
        allow(Readme).to receive(:new).and_return(fake_readme)
      end

      it "renders view to upload the readme" do
        sign_in user
        get :readme_select, params: { id: work.id }
        expect(response).to render_template(:readme_select)
        expect(assigns[:readme]).to eq("README.txt")
      end
    end

    describe "#readme_uploaded" do
      let(:attach_status) { nil }
      let(:fake_readme) { instance_double Readme, attach: attach_status, "blank?": true }
      let(:params) do
        {
          "_method" => "patch",
          "authenticity_token" => "MbUfIQVvYoCefkOfSpzyS0EOuSuOYQG21nw8zgg2GVrvcebBYI6jy1-_3LSzbTg9uKgehxWauYS8r1yxcN1Lwg",
          "patch" => {
            "readme_file" => uploaded_file
          },
          "commit" => "Continue",
          "controller" => "works",
          "action" => "file_uploaded",
          "id" => work.id
        }
      end

      before do
        allow(Readme).to receive(:new).and_return(fake_readme)
        sign_in user
        post :readme_uploaded, params: params
      end

      it "redirects to file-upload" do
        expect(response.status).to be 302
        expect(fake_readme).to have_received(:attach)
        expect(response.location).to eq "http://test.host/works/#{work.id}/attachment-select"
      end

      context "the upload encounters an error" do
        let(:attach_status) { "An error occured" }

        it "Stays on the same page" do
          expect(response).to redirect_to(work_readme_select_path(work))
          expect(controller.flash[:notice]).to eq("An error occured")
        end
      end
    end

    it "renders view to select the kind of attachment to use" do
      sign_in user
      get :attachment_select, params: { id: work.id }
      expect(response).to render_template(:attachment_select)
    end

    describe "#attachment_selected" do
      let(:attachment_type) { "file_upload" }
      let(:fake_s3_service) { stub_s3 }
      before do
        fake_s3_service
        sign_in user
        post :attachment_selected, params: { id: work.id, attachment_type: attachment_type }
      end

      it "redirects to file-upload" do
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}/file-upload"
        expect(fake_s3_service).not_to have_received(:create_directory)
      end

      context "when type is file_cluster" do
        let(:attachment_type) { "file_cluster" }

        it "redirects to file-cluster" do
          expect(response.status).to be 302
          expect(response.location).to eq "http://test.host/works/#{work.id}/file-cluster"
          expect(fake_s3_service).to have_received(:create_directory)
        end
      end

      context "when type is file_other" do
        let(:attachment_type) { "file_other" }

        it "redirects to file-other" do
          expect(response.status).to be 302
          expect(response.location).to eq "http://test.host/works/#{work.id}/file-other"
          expect(fake_s3_service).to have_received(:create_directory)
        end
      end
    end

    it "renders the page to upload files directly" do
      sign_in user
      get :file_upload, params: { id: work.id }
      expect(response).to render_template(:file_upload)
    end

    context "with an uploaded CSV file" do
      let(:fake_s3_service) { stub_s3 }
      let(:params) do
        {
          "_method" => "patch",
          "authenticity_token" => "MbUfIQVvYoCefkOfSpzyS0EOuSuOYQG21nw8zgg2GVrvcebBYI6jy1-_3LSzbTg9uKgehxWauYS8r1yxcN1Lwg",
          "patch" => {
            "pre_curation_uploads" => [uploaded_file]
          },
          "commit" => "Continue",
          "controller" => "works",
          "action" => "file_uploaded",
          "id" => work.id
        }
      end

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      before do
        sign_in user
        fake_s3_service # make sure the s3 service is mocked here
        post :file_uploaded, params: params
        perform_enqueued_jobs
      end

      it "upload files directly from user requests" do
        expect(response).to redirect_to(work_review_path)
        expect(fake_s3_service).to have_received(:upload_file).with(hash_including(filename: "us_covid_2019.csv"))
      end

      context "when files are not specified within the parameters" do
        let(:params) do
          {
            "_method" => "patch",
            "authenticity_token" => "MbUfIQVvYoCefkOfSpzyS0EOuSuOYQG21nw8zgg2GVrvcebBYI6jy1-_3LSzbTg9uKgehxWauYS8r1yxcN1Lwg",
            "patch" => {},
            "commit" => "Continue",
            "controller" => "works",
            "action" => "file_uploaded",
            "id" => work.id
          }
        end

        it "does not update the work" do
          expect(response).to redirect_to(work_review_path)
          expect(fake_s3_service).not_to have_received(:upload_file)
        end
      end
    end

    context "when file uploads raise errors" do
      let(:params) do
        {
          "_method" => "patch",
          "authenticity_token" => "MbUfIQVvYoCefkOfSpzyS0EOuSuOYQG21nw8zgg2GVrvcebBYI6jy1-_3LSzbTg9uKgehxWauYS8r1yxcN1Lwg",
          "patch" => {
            "pre_curation_uploads" => [uploaded_file]
          },
          "commit" => "Continue",
          "controller" => "works",
          "action" => "file_uploaded",
          "id" => work.id
        }
      end

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      let(:persisted) do
        instance_double(Work, id: work.id, upload_snapshots: [], to_s: work.id, doi: work.doi, s3_query_service: nil)
      end

      before do
        sign_in user
        work.save

        allow(Rails.logger).to receive(:error)
        allow(Work).to receive(:find).and_return(persisted)
        allow(persisted).to receive(:changes).and_raise("Error!")

        post :file_uploaded, params: params
      end

      it "does not update the work and renders an error messages" do
        # TODO: - how do we tell the user there was an error now that this in not in the page context?
        # This error that is happening seems to be just a random error so it is ok that we still capture that
        expect(response).to redirect_to(work_file_upload_path(work))
        expect(controller.flash[:notice].start_with?("Failed to attach the file uploads for the work #{work.doi}")).to be true
        expect(Rails.logger).to have_received(:error).with(/Failed to attach the file uploads for the work #{work.doi}/)
      end
    end

    it "renders the page to indicate instructions on files on the PUL Research Cluster" do
      sign_in user
      get :file_cluster, params: { id: work.id }
      expect(response).to render_template(:file_cluster)
    end

    it "renders the page to indicate instructions on files on a different location" do
      sign_in user
      get :file_other, params: { id: work.id }
      expect(response).to render_template(:file_other)
    end

    it "renders the review page and saves the location notes" do
      sign_in user
      post :review, params: { id: work.id, location_notes: "my files can be found at http://aws/my/data" }
      expect(response).to render_template(:review)
      expect(Work.find(work.id).location_notes).to eq "my files can be found at http://aws/my/data"
    end

    describe "#show" do
      before do
        sign_in user
        stub_s3 data: data
      end

      let(:data) { [] }

      it "renders the workshow page" do
        get :show, params: { id: work.id }
        expect(response).to render_template("show")
        expect(assigns[:work_decorator].changes).to eq([])
        expect(assigns[:work_decorator].messages).to eq([])
      end

      context "when the work has changes and messages" do
        before do
          WorkActivity.add_work_activity(work.id, "Hello System", user.id, activity_type: WorkActivity::SYSTEM)
          work.add_message("Hello World", user.id)
        end

        it "renders the workshow page" do
          get :show, params: { id: work.id }
          expect(response).to render_template("show")
          expect(assigns[:work_decorator].changes.map(&:message)).to eq(["Hello System"])
          expect(assigns[:work_decorator].messages.map(&:message)).to eq(["Hello World"])
        end
      end
    end

    describe "#file_list" do
      before do
        sign_in user
      end

      let(:file1) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_README.txt", work: work }
      let(:file2) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/something.jpg", work: work }

      let(:data) { [file1, file2] }
      let(:fake_s3_service) { stub_s3(data: data) }

      it "returns file list in JSON" do
        allow(fake_s3_service).to receive(:client_s3_files).and_return(data)

        get :file_list, params: { id: work.id }
        file_list = JSON.parse(response.body)
        expect(file_list.map { |f| f["filename"] }.sort).to eq(["10.34770/123-abc/#{work.id}/SCoData_combined_v1_2020-07_README.txt", "10.34770/123-abc/#{work.id}/something.jpg"])

        # Check that we don't accidentally serialize the Work as part of the JSON file list.
        # Including the work is bad for large records, because if for example a Work has 500 files
        # and we include the Work in the file list we will be including the 500 files 500 times.
        expect(file_list[0].keys.include?("work")). to be false
      end
    end

    describe "ID redirection" do
      describe "#resolve_doi" do
        before do
          sign_in user
          stub_s3 data: data
        end

        let(:data) { [] }
        let(:work) { FactoryBot.create(:shakespeare_and_company_work) }

        it "redirects to the Work show view" do
          stub_s3
          get :resolve_doi, params: { doi: work.doi }
          expect(response).to redirect_to(work_path(work))
        end

        context "when passing only a segment of the DOI" do
          it "redirects to the Work show view if missing prefix" do
            stub_s3
            prefix = "10.34770/"
            expect(work.doi).to start_with(prefix)
            get :resolve_doi, params: { doi: work.doi.gsub(prefix, "") }
            expect(response).to redirect_to(work_path(work))
          end

          it "does not redirect to the Work show view if not exact (missing slash)" do
            stub_s3
            expect do
              get :resolve_doi, params: { doi: work.doi.gsub("10.34770", "") }
            end.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end

      describe "#resolve_ark" do
        before do
          sign_in user
          stub_s3 data: data
        end

        let(:data) { [] }
        let(:work) { FactoryBot.create(:shakespeare_and_company_work) }

        it "redirects to the Work show view" do
          stub_s3
          get :resolve_ark, params: { ark: work.ark }
          expect(response).to redirect_to(work_path(work))
        end

        context "when passing only a segment of the ARK" do
          it "redirects to the Work show view if missing prefix" do
            stub_s3
            prefix = "ark:/"
            expect(work.ark).to start_with(prefix)
            get :resolve_ark, params: { ark: work.ark.gsub(prefix, "") }
            expect(response).to redirect_to(work_path(work))
          end

          it "does not redirect to the Work show view if not exact (missing slash)" do
            stub_s3
            expect do
              get :resolve_ark, params: { ark: work.ark.gsub("ark:", "") }
            end.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    describe "#validate" do
      before do
        stub_s3
      end

      it "saves the submission notes and renders the user dashboard" do
        sign_in user
        post :validate, params: { id: work.id, submission_notes: "I need this processed ASAP" }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/users/#{user.uid}"
        expect(Work.find(work.id).submission_notes).to eq "I need this processed ASAP"
      end

      context "an invalid work" do
        it "handles completion errors" do
          work.resource.description = nil
          work.save
          sign_in user
          post :validate, params: { id: work.id }
          expect(response).to render_template("edit")
          expect(response.status).to be 422
          expect(work.reload).to be_draft
          expect(assigns[:errors]).to eq(["Cannot Complete submission: Must provide a description"])
        end
      end
    end

    describe "#approve" do
      before do
        stub_s3 data: [FactoryBot.build(:s3_file)]
        allow(Work).to receive(:find).with(work.id).and_return(work)
        allow(Work).to receive(:find).with(work.id.to_s).and_return(work)
        allow(work).to receive(:publish_precurated_files).and_return(true)
      end

      it "handles aprovals" do
        work.complete_submission!(user)
        stub_datacite_doi

        sign_in curator
        post :approve, params: { id: work.id }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}"
        expect(work.reload).to be_approved
        expect(controller.flash[:notice]).to eq("Your files are being moved to the post-curation bucket in the background. Depending on the file sizes this may take some time.")
      end

      context "invalid response from doi publish" do
        before do
          sign_in curator
          work.complete_submission!(user)
          stub_datacite_doi(result: Failure(Faraday::Response.new(Faraday::Env.new)))
        end

        it "aproves and notes that it was not published" do
          post :approve, params: { id: work.id }
          expect(response.status).to be 302
          expect(response.location).to eq "http://test.host/works/#{work.id}"
          expect(work.reload).to be_approved
          error = work.work_activity.find { |activity| activity.activity_type == WorkActivity::DATACITE_ERROR }
          expect(error.message).to include("Error publishing DOI")
        end
      end

      context "work not completed" do
        it "handles aproval errors" do
          sign_in curator
          post :approve, params: { id: work.id }
          expect(response.status).to be 422
          expect(work.reload).to be_draft
          expect(assigns[:errors]).to eq(["Cannot Approve: Event 'approve' cannot transition from 'draft'."])
        end
      end

      context "no files attached" do
        it "handles aproval errors" do
          work.complete_submission!(user)
          stub_s3 data: []
          sign_in curator
          post :approve, params: { id: work.id }
          expect(response.status).to be 422
          expect(assigns[:errors]).to eq(["Cannot Approve: Uploads must be present for a work to be approved"])
        end
      end

      context "work submitter is trying to approve" do
        let(:user) { FactoryBot.create(:princeton_submitter) }

        it "handles aproval errors" do
          sign_in user
          work.complete_submission!(user)
          stub_datacite_doi
          post :approve, params: { id: work.id }
          expect(response.status).to be 422
          expect(work.reload).to be_awaiting_approval
          expect(assigns[:errors]).to eq(["Cannot Approve: Unauthorized to Approve"])
        end
      end

      context "when approving as a non-curator" do
        let(:user) { FactoryBot.create(:pppl_submitter) }

        before do
          sign_in user
          work.complete_submission!(user)
          stub_datacite_doi
          post :approve, params: { id: work.id }
        end

        it "raises an error" do
          expect(response.status).to be 422
        end
      end

      context "when approving as a non-super-admin" do
        let(:user) { FactoryBot.create(:user) }

        before do
          sign_in user
          work.complete_submission!(user)
          stub_datacite_doi
          post :approve, params: { id: work.id }
        end

        it "responds with a status code of 422" do
          expect(response.status).to be 422
        end
      end
    end

    describe "#withdraw" do
      it "handles withdraw" do
        sign_in user
        post :withdraw, params: { id: work.id }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}"
        expect(work.reload).to be_withdrawn
      end

      context "a deletion_markerd work" do
        it "handles withdraw errors" do
          work.withdraw(user)
          work.remove!(user)
          sign_in user
          post :withdraw, params: { id: work.id }
          expect(response.status).to be 422
          expect(work.reload).to be_deletion_marker
          expect(assigns[:errors]).to eq(["Cannot Withdraw: Event 'withdraw' cannot transition from 'deletion_marker'."])
        end
      end
    end

    describe "#resubmit" do
      it "handles resubmit" do
        sign_in user
        work.withdraw!(user)
        post :resubmit, params: { id: work.id }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}"
        expect(work.reload).to be_draft
      end

      context "an active work" do
        it "handles resubmit errors" do
          sign_in user
          post :resubmit, params: { id: work.id }
          expect(response.status).to be 422
          expect(work.reload).to be_draft
          expect(assigns[:errors]).to eq(["Cannot Resubmit: Event 'resubmit' cannot transition from 'draft'."])
        end
      end
    end

    it "renders datacite serialization as XML" do
      sign_in user
      get :datacite, params: { id: work.id }
      expect(response.body.start_with?('<?xml version="1.0"?>')).to be true
    end

    it "handles change curator" do
      sign_in user
      put :assign_curator, params: { id: work.id, uid: curator.id }
      expect(response.status).to be 200
      expect(response.body).to eq "{}"
    end

    it "handles clear curator" do
      sign_in user
      put :assign_curator, params: { id: work.id, uid: "no-one" }
      expect(response.status).to be 200
      expect(response.body).to eq "{}"
    end

    it "handles error setting the curator" do
      sign_in user
      put :assign_curator, params: { id: work.id, uid: "-1" }
      expect(response.status).to be 400
      expect(response.body).to eq '{"errors":["Cannot save dataset"]}'
    end

    it "posts a message" do
      sign_in user
      post :add_message, params: { id: work.id, "new-message" => "hello world" }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"
    end

    context "when posting a message containing HTML" do
      render_views

      it "adds to change history with a date and markdown" do
        stub_s3
        sign_in user
        stub_s3
        post :add_provenance_note, params: { id: work.id, "new-provenance-note" => "<span>hello</span> _world_", "new-provenance-date" => "2000-01-01" }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}"
        get :show, params: { id: work.id }
        expect(response.body).to include("&lt;span&gt;hello&lt;/span&gt; <em>world</em>")
        expect(response.body).to include("January 01, 2000")
      end

      it "posts a message with sanitized HTML" do
        sign_in user
        # The ERB only shows the form to a subset of users,
        # but the endpoint has no such restriction: Anyone can POST.
        # In some contexts, a hole like this would be a security problem,
        # but this is low-stakes.
        post :add_message, params: { id: work.id, "new-message" => "<div>hello world</div>" }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}"
        stub_s3
        get :show, params: { id: work.id }
        expect(response.body).not_to include("<div>hello world</div>")
        expect(response.body).to include("&lt;div&gt;hello world&lt;/div&gt;")
      end
    end
  end

  describe "#update" do
    let(:params) do
      {
        id: work.id,
        title_main: work.title,
        group_id: group.id,
        new_title_1: "the subtitle",
        new_title_type_1: "Subtitle",
        existing_title_count: "1",
        new_title_count: "1",
        "creators" => [{ "orcid" => "", "given_name" => "Toni", "family_name" => "Morrison" },
                       { "orcid" => "1234-1234-1234-1234", "given_name" => "Sonia", "family_name" => "Sotomayor" }],
        rights_identifiers: ["CC BY"],
        description: "a new description"
      }
    end
    before do
      stub_s3
    end

    context "when authenticated" do
      before do
        sign_in user
      end
      context "when requesting a HTML representation" do
        let(:format) { :html }

        context "when the update succeeds" do
          before do
            patch :update, params: params
          end

          it "redirects to the show page" do
            expect(response.code).to eq("302")
            expect(response).to redirect_to(work_path(work))
          end
        end

        context "a submitter trying to update the curator conrolled fields" do
          before do
            new_params = params.merge(doi: "new-doi")
                               .merge(ark: "new-ark")
                               .merge(collection_tags: "new-collection-tags")
                               .merge(resource_type: "digitized video")
                               .merge(resource_type_general: Datacite::Mapping::ResourceTypeGeneral::AUDIOVISUAL.value)
            patch :update, params: new_params
          end

          it "also saves the curator controlled fields", mock_ezid_api: true do
            expect(work.reload.doi).to eq("new-doi")
            expect(work.ark).to eq("new-ark")
            expect(work.resource.collection_tags).to eq(["new-collection-tags"])
          end
        end

        context "a group admin trying to update curator controlled fields" do
          let(:user) { FactoryBot.create :research_data_moderator }
          before do
            new_params = params.merge(doi: "new-doi")
                               .merge(ark: "new-ark")
                               .merge(collection_tags: "new-colletion-tag1, new-collection-tag2")
                               .merge(resource_type: "digitized video")
                               .merge(resource_type_general: Datacite::Mapping::ResourceTypeGeneral::AUDIOVISUAL.value)

            patch :update, params: new_params
          end

          it "updates the curator controlled fields", mock_ezid_api: true do
            expect(work.reload.doi).to eq("new-doi")
            expect(work.ark).to eq("new-ark")
            expect(work.resource.collection_tags).to eq(["new-colletion-tag1", "new-collection-tag2"])
            expect(work.resource_type).to eq("digitized video")
            expect(work.resource_type_general).to eq(::Datacite::Mapping::ResourceTypeGeneral::AUDIOVISUAL.value)
          end
        end

        context "when the update fails" do
          before do
            allow(Work).to receive(:find).and_return(work)
            allow(work).to receive(:update).and_return(false)
            patch :update, params: params
          end

          it "renders the edit view with a 422 response status code" do
            expect(response.code).to eq("422")
            expect(response).to render_template(:edit)
          end
        end

        context "when sending a nil group" do
          before do
            params[:group_id] = nil
            allow(Honeybadger).to receive(:notify)
          end
          it "uses the updators default group" do
            patch :update, params: params
            expect(work.reload.group).to eq(user.default_group)
            expect(Honeybadger).to have_received(:notify)
          end
        end
      end

      context "when requesting a JSON representation" do
        let(:format) { :json }

        context "when the update fails" do
          before do
            sign_in user
            allow(Work).to receive(:find).and_return(work)
            allow_any_instance_of(Work).to receive(:update).and_return(false)
            patch :update, params: params
          end

          it "renders JSON-serialized error messages with a 422 response status code" do
            expect(response.code).to eq("422")
          end
        end
      end
    end

    context "the work is approved" do
      let(:work) { FactoryBot.create :approved_work }
      let(:new_params) { params.merge(doi: "new-doi").merge(ark: "ark:/99999/new-ark").merge(collection_tags: "new-colletion-tag1, new-collection-tag2") }

      context "the submitter" do
        let(:user) { work.created_by_user }

        it "redirects the home page on edit with informational message" do
          sign_in user
          patch :update, params: new_params
          expect(response).to redirect_to(root_path)
          expect(controller.flash[:notice]).to eq("This work has been approved.  Edits are no longer available.")
        end
      end
      context "another user" do
        let(:other_user) { FactoryBot.create(:user) }
        it "redirects the home page on edit" do
          sign_in other_user
          patch :update, params: new_params
          expect(response).to redirect_to(root_path)
        end
      end
      context "a curator", mock_ezid_api: true do
        let(:user) { FactoryBot.create(:research_data_moderator) }
        it "renders the edit page on edit" do
          stub_s3
          sign_in user
          patch :update, params: new_params
          expect(work.reload.doi).to eq("new-doi")
          expect(work.ark).to eq("ark:/99999/new-ark")
          expect(work.resource.collection_tags).to eq(["new-colletion-tag1", "new-collection-tag2"])
        end
      end

      context "the submitter is the curator" do
        let(:work) { FactoryBot.create(:approved_work, created_by_user_id: curator.id) }

        it "renders the edit page on edit" do
          sign_in curator
          patch :update, params: new_params
          expect(work.reload.doi).to eq("new-doi")
          expect(work.ark).to eq("ark:/99999/new-ark")
          expect(work.resource.collection_tags).to eq(["new-colletion-tag1", "new-collection-tag2"])
        end
      end
      context "a super admin", mock_ezid_api: true do
        let(:user) { FactoryBot.create(:super_admin_user) }
        it "renders the edit page on edit" do
          stub_s3
          sign_in user
          patch :update, params: new_params
          expect(work.reload.doi).to eq("new-doi")
          expect(work.ark).to eq("ark:/99999/new-ark")
          expect(work.resource.collection_tags).to eq(["new-colletion-tag1", "new-collection-tag2"])
        end
      end
    end
  end

  describe "#assign_curator" do
    let(:errors) { double }
    let(:current_work) { instance_double(Work) }
    let(:params) do
      {
        id: current_work.id,
        uid: "test_user"
      }
    end

    context "when the request parameters are invalid" do
      it "responds with 400 status code and the validation errors" do
        stub_s3
        sign_in user
        allow(errors).to receive(:map).and_return(["test error"])
        allow(errors).to receive(:count).and_return(1)
        allow(current_work).to receive(:errors).and_return(errors)
        allow(current_work).to receive(:change_curator).and_return(false)
        allow(current_work).to receive(:id).and_return("test_id")
        allow(Work).to receive(:find).and_return(current_work)
        put :assign_curator, params: params

        expect(response.code).to eq("400")
        expect(response.content_type).to eq("application/json; charset=utf-8")
        json_body = JSON.parse(response.body)
        expect(json_body).to include("errors" => ["test error"])
      end
    end
  end

  describe "#edit" do
    it "renders the edit page on edit" do
      stub_s3
      sign_in user
      get :edit, params: { id: work.id }
      expect(response).to render_template("edit")
    end

    context "the work is approved" do
      let(:work) { FactoryBot.create :approved_work }
      context "the submitter" do
        let(:user) { work.created_by_user }

        it "redirects the home page on edit with informational message" do
          sign_in user
          get :edit, params: { id: work.id }
          expect(response).to redirect_to(root_path)
          expect(controller.flash[:notice]).to eq("This work has been approved.  Edits are no longer available.")
        end
      end
      context "another user" do
        let(:other_user) { FactoryBot.create(:user) }
        it "redirects the home page on edit" do
          sign_in other_user
          get :edit, params: { id: work.id }
          expect(response).to redirect_to(root_path)
        end
      end
      context "a curator" do
        let(:user) { FactoryBot.create(:research_data_moderator) }
        it "renders the edit page on edit" do
          stub_s3
          sign_in user
          get :edit, params: { id: work.id }
          expect(response).to render_template("edit")
        end
      end
      context "a super admin" do
        let(:user) { FactoryBot.create(:super_admin_user) }
        it "renders the edit page on edit" do
          stub_s3
          sign_in user
          get :edit, params: { id: work.id }
          expect(response).to render_template("edit")
        end
      end
    end
  end

  describe "#create" do
    it "creates a work" do
      params = {
        "title_main" => "test dataset updated",
        "description" => "a new description",
        "group_id" => group.id,
        "commit" => "Update Dataset",
        "publisher" => "Princeton University",
        "publication_year" => "2022",
        "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
        "resource_type" => "Dataset",
        "resource_type_general" => "Dataset"
      }
      sign_in user
      expect { post :create, params: params }.to change { Work.count }.by 1
      work = Work.last
      expect(work.title).to eq("test dataset updated")
      expect(work.resource.description).to eq("a new description")
      expect(work.group).to eq(group)
    end

    it "defaults the right values for a PPPL work" do
      params = {
        "title_main" => "test dataset updated",
        "description" => "a new description",
        "commit" => "Update Dataset",
        "publication_year" => "2022",
        "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
        "resource_type" => "Dataset",
        "resource_type_general" => "Dataset"
      }
      sign_in pppl_user
      post :create, params: params
      work = Work.last
      expect(work.resource.publisher).to eq "Princeton Plasma Physics Laboratory, Princeton University"
    end

    context "when the group is empty" do
      it "creates a work in the user's default group" do
        params = {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => "",
          "commit" => "Update Dataset",
          "publisher" => "Princeton University",
          "publication_year" => "2022",
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }],
          "resource_type" => "Dataset",
          "resource_type_general" => "Dataset"
        }
        sign_in user
        expect { post :create, params: params }.to change { Work.count }.by 1
        work = Work.last
        expect(work.title).to eq("test dataset updated")
        expect(work.resource.description).to eq("a new description")
        expect(work.group).to eq(user.default_group)
      end
    end
  end
end
