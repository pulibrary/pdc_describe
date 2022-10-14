# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorksController do
  before do
    Collection.create_defaults
    user
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original
  end
  let(:curator) { FactoryBot.create(:user, collections_to_admin: [collection]) }
  let(:collection) { Collection.first }
  let(:resource) { FactoryBot.build :resource }
  let(:work) { FactoryBot.create(:draft_work) }
  let(:user) { work.created_by_user }

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

    it "renders the resource json" do
      sign_in user
      stub_s3
      get :show, params: { id: work.id, format: "json" }
      expect(response.content_type).to eq "application/json; charset=utf-8"
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
        "collection_id" => work.collection.id,
        "given_name_1" => "Jane",
        "family_name_1" => "Smith",
        "creator_count" => "1"
      }
      sign_in user
      post :new_submission, params: params
      expect(response.status).to be 302
      expect(response.location.start_with?("http://test.host/works/")).to be true
    end

    it "handles the update page" do
      params = {
        "title_main" => "test dataset updated",
        "description" => "a new description",
        "collection_id" => work.collection.id,
        "commit" => "Update Dataset",
        "controller" => "works",
        "action" => "update",
        "id" => work.id.to_s,
        "publisher" => "Princeton University",
        "publication_year" => "2022",
        "given_name_1" => "Jane",
        "family_name_1" => "Smith",
        "creator_count" => "1",
        "resource_type" => "Dataset",
        "resource_type_general" => "dataset"
      }
      sign_in user
      post :update, params: params
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"

      work.reload
      expect(work.resource_type).to eq("Dataset")
      expect(work.resource_type_general).to eq(:DATASET)
      expect(ActiveStorage::PurgeJob).not_to have_received(:new)
    end

    context "when the client uses wizard mode" do
      it "updates the Work and redirects the client to select attachments" do
        params = {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "collection_id" => work.collection.id,
          "commit" => "Update Dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "wizard" => "true",
          "publisher" => "Princeton University",
          "publication_year" => "2022",
          "given_name_1" => "Jane",
          "family_name_1" => "Smith",
          "creator_count" => "1"
        }
        sign_in user
        post :update, params: params
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}/attachment-select"
        expect(ActiveStorage::PurgeJob).not_to have_received(:new)
      end
    end

    it "handles the reordering the creators on the update page" do
      params = {
        "doi" => "10.34770/tbd",
        "title_main" => "test dataset updated",
        "description" => "a new description",
        "collection_id" => work.collection.id,
        "commit" => "Update Dataset",
        "controller" => "works",
        "action" => "update",
        "id" => work.id.to_s,
        "publisher" => "Princeton University",
        "publication_year" => "2022",
        "given_name_1" => "Jane",
        "family_name_1" => "Smith",
        "sequence_1" => "1",
        "given_name_2" => "Ada",
        "family_name_2" => "Lovelace",
        "sequence_2" => "2",
        "creator_count" => "2"
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
        "collection_id" => work.collection.id,
        "commit" => "Update Dataset",
        "controller" => "works",
        "action" => "update",
        "id" => work.id.to_s,
        "publisher" => "Princeton University",
        "publication_year" => "2022",
        "given_name_1" => "Jane",
        "family_name_1" => "Smith",
        "sequence_1" => "2",
        "given_name_2" => "Ada",
        "family_name_2" => "Lovelace",
        "sequence_2" => "1",
        "creator_count" => "2"
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
      let(:uploaded_file) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      before do
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
      end

      it "handles the update page" do
        params = {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "collection_id" => work.collection.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "given_name_1" => "jane",
          "family_name_1" => "smith",
          "sequence_1" => "1",
          "given_name_2" => "ada",
          "family_name_2" => "lovelace",
          "sequence_2" => "2",
          "creator_count" => "2",
          "pre_curation_uploads" => uploaded_file
        }
        sign_in user
        expect(work.pre_curation_uploads).to be_empty
        post :update, params: params

        saved_work = Work.find(work.id)

        expect(saved_work.pre_curation_uploads).not_to be_empty
        expect(ActiveStorage::PurgeJob).not_to have_received(:new)
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

      before do
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
      end

      it "handles the update page" do
        params = {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "collection_id" => work.collection.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "given_name_1" => "jane",
          "family_name_1" => "smith",
          "sequence_1" => "1",
          "given_name_2" => "ada",
          "family_name_2" => "lovelace",
          "sequence_2" => "2",
          "creator_count" => "2",
          "pre_curation_uploads" => uploaded_files
        }
        sign_in user
        expect(work.pre_curation_uploads).to be_empty
        post :update, params: params

        saved_work = Work.find(work.id)

        expect(saved_work.pre_curation_uploads).not_to be_empty
        expect(ActiveStorage::PurgeJob).not_to have_received(:new)
      end
    end

    context "when only some file uploads are replaced for an existing Work with uploads" do
      let(:uploaded_file1) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:temp_file1) do
        file = Tempfile.new("temp_file1")
        file.write("hello world")
        file.close
        file
      end
      let(:uploaced_temp_file1) { Rack::Test::UploadedFile.new(temp_file1.path, "text/plain") }
      let(:temp_file2) do
        file = Tempfile.new("temp_file2")
        file.write("hello world 2")
        file.close
        file
      end
      let(:uploaced_temp_file2) { Rack::Test::UploadedFile.new(temp_file2.path, "text/plain") }
      let(:temp_file3) do
        file = Tempfile.new("temp_file3")
        file.write("hello world 3")
        file.close
        file
      end
      let(:uploaced_temp_file3) { Rack::Test::UploadedFile.new(temp_file3.path, "text/plain") }

      after do
        temp_file1.unlink
        temp_file2.unlink
        temp_file3.unlink
      end

      let(:uploaded_file2) do
        fixture_file_upload("us_covid_2020.csv", "text/csv")
      end

      let(:uploaded_files) do
        {
          "0" => uploaded_file1,
          "2" => uploaded_file2
        }
      end

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      before do
        stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)

        work.pre_curation_uploads.attach(uploaced_temp_file1)
        work.pre_curation_uploads.attach(uploaced_temp_file2)
        work.pre_curation_uploads.attach(uploaced_temp_file3)

        params = {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "collection_id" => work.collection.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "given_name_1" => "jane",
          "family_name_1" => "smith",
          "sequence_1" => "1",
          "given_name_2" => "ada",
          "family_name_2" => "lovelace",
          "sequence_2" => "2",
          "creator_count" => "2",
          "replaced_uploads" => uploaded_files
        }
        sign_in user
        post :update, params: params
      end

      it "handles the update page" do
        saved_work = Work.find(work.id)

        expect(saved_work.pre_curation_uploads).not_to be_empty
        expect(saved_work.pre_curation_uploads.length).to eq(3)

        # Remeber! Order is alpabetical
        expect(saved_work.pre_curation_uploads[0].blob.filename.to_s).to eq(File.basename(temp_file2.path))
        expect(saved_work.pre_curation_uploads[1].filename.to_s).to eq("us_covid_2019.csv")
        expect(saved_work.pre_curation_uploads[2].filename.to_s).to eq("us_covid_2020.csv")
        expect(ActiveStorage::PurgeJob).not_to have_received(:new)
      end
    end

    context "when only some file uploads are deleted for an existing Work with uploads" do
      let(:uploaded_file1) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:uploaded_file2) do
        fixture_file_upload("us_covid_2020.csv", "text/csv")
      end

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      let(:deleted_uploads) do
        # "1" indicates that the file has been deleted
        {
          work.pre_curation_uploads.first.key => "1",
          work.pre_curation_uploads[1].key => "0",
          work.pre_curation_uploads.last.key => "1"
        }
      end

      let(:params) do
        {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "collection_id" => work.collection.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "given_name_1" => "jane",
          "family_name_1" => "smith",
          "sequence_1" => "1",
          "given_name_2" => "ada",
          "family_name_2" => "lovelace",
          "sequence_2" => "2",
          "creator_count" => "2",
          "deleted_uploads" => deleted_uploads
        }
      end

      # Notice that we do NOT pass "deleted_uploads" on purpose
      let(:params_no_delete) do
        {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "collection_id" => work.collection.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "given_name_1" => "jane",
          "family_name_1" => "smith",
          "sequence_1" => "1",
          "given_name_2" => "ada",
          "family_name_2" => "lovelace",
          "sequence_2" => "2",
          "creator_count" => "2",
          "rights_identifier" => "CC BY"
        }.with_indifferent_access
      end

      before do
        stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
      end

      context "when the Work has not been curated" do
        before do
          work.pre_curation_uploads.attach(uploaded_file1)
          work.pre_curation_uploads.attach(uploaded_file1)
          work.pre_curation_uploads.attach(uploaded_file1)
        end

        it "handles the update page" do
          expect(work.pre_curation_uploads.length).to eq(3)

          sign_in user
          post :update, params: params

          saved_work = Work.find(work.id)

          expect(saved_work.pre_curation_uploads).not_to be_empty
          expect(saved_work.pre_curation_uploads.length).to eq(1)

          expect(saved_work.pre_curation_uploads[0].blob.filename.to_s).to eq("us_covid_2019.csv")
          expect(ActiveStorage::PurgeJob).not_to have_received(:new)
        end
      end

      context "when the Work has been curated", mock_s3_query_service: false do
        let(:work) { FactoryBot.create(:completed_work) }
        let(:user) do
          FactoryBot.create :user, collections_to_admin: [work.collection]
        end
        let(:s3_query_service_double) { instance_double(S3QueryService) }
        let(:file1) do
          S3File.new(
            filename: "SCoData_combined_v1_2020-07_README.txt",
            last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
            size: 10_759,
            checksum: "abc123"
          )
        end
        let(:file2) do
          S3File.new(
            filename: "SCoData_combined_v1_2020-07_datapackage.json",
            last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
            size: 12_739,
            checksum: "abc567"
          )
        end
        let(:s3_data) { [file1, file2] }
        let(:bucket_url) do
          "https://example-bucket.s3.amazonaws.com/"
        end
        let(:deleted_uploads) do
          # "1" indicates that the file has been delete
          {
            work.post_curation_uploads.first.key => "1",
            work.post_curation_uploads[1].key => "0",
            work.post_curation_uploads.last.key => "1"
          }
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
          work.pre_curation_uploads.attach(uploaded_file)
          work.approve!(user)

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

    context "when file uploads are resent for an existing Work with uploads" do
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

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      let(:request_params) do
        {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "collection_id" => work.collection.id,
          "commit" => "update dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "princeton university",
          "publication_year" => "2022",
          "given_name_1" => "jane",
          "family_name_1" => "smith",
          "sequence_1" => "1",
          "given_name_2" => "ada",
          "family_name_2" => "lovelace",
          "sequence_2" => "2",
          "creator_count" => "2",
          "pre_curation_uploads" => uploaded_files
        }
      end

      before do
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
        stub_request(:delete, /#{bucket_url}/).to_return(status: 200)

        work.pre_curation_uploads.attach(uploaded_file1)
        work.pre_curation_uploads.attach(uploaded_file2)
        work.reload

        sign_in user
      end

      it "handles the update page" do
        expect(work.pre_curation_uploads).not_to be_empty
        expect(work.pre_curation_uploads.first).to be_an(ActiveStorage::Attachment)

        post :update, params: request_params

        saved_work = Work.find(work.id)

        expect(saved_work.pre_curation_uploads).not_to be_empty
        expect(work.pre_curation_uploads.first).to be_an(ActiveStorage::Attachment)

        # order is alphabetical, we can not change it by sending the files in a different order
        expect(saved_work.pre_curation_uploads.first.filename).to eq(uploaded_files.first.original_filename)
        expect(saved_work.pre_curation_uploads.last.filename).to eq(uploaded_files.last.original_filename)

        # original copies of the files get deleted
        expect(a_request(:delete, /#{bucket_url}/)).to have_been_made.twice
        expect(ActiveStorage::PurgeJob).not_to have_received(:new)
      end
    end

    it "renders view to select the kind of attachment to use" do
      sign_in user
      get :attachment_select, params: { id: work.id }
      expect(response).to render_template(:attachment_select)
    end

    it "redirects to the proper step depending on the attachment type" do
      sign_in user
      post :attachment_selected, params: { id: work.id, attachment_type: "file_upload" }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}/file-upload"

      post :attachment_selected, params: { id: work.id, attachment_type: "file_cluster" }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}/file-cluster"

      post :attachment_selected, params: { id: work.id, attachment_type: "file_other" }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}/file-other"
    end

    it "renders the page to upload files directly" do
      sign_in user
      get :file_upload, params: { id: work.id }
      expect(response).to render_template(:file_upload)
    end

    context "with an uploaded CSV file" do
      let(:uploaded_file) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:params) do
        {
          "_method" => "patch",
          "authenticity_token" => "MbUfIQVvYoCefkOfSpzyS0EOuSuOYQG21nw8zgg2GVrvcebBYI6jy1-_3LSzbTg9uKgehxWauYS8r1yxcN1Lwg",
          "patch" => {
            "pre_curation_uploads" => uploaded_file
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
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)
        sign_in user
        post :file_uploaded, params: params
      end

      it "upload files directly from user requests" do
        expect(response).to redirect_to(work_review_path)
        reloaded = work.reload
        expect(reloaded.pre_curation_uploads).not_to be_empty
        expect(reloaded.pre_curation_uploads.first).to be_an(ActiveStorage::Attachment)
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
          reloaded = work.reload
          expect(reloaded.pre_curation_uploads).to be_empty
        end
      end
    end

    context "when file uploads raise errors" do
      let(:uploaded_file) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:params) do
        {
          "_method" => "patch",
          "authenticity_token" => "MbUfIQVvYoCefkOfSpzyS0EOuSuOYQG21nw8zgg2GVrvcebBYI6jy1-_3LSzbTg9uKgehxWauYS8r1yxcN1Lwg",
          "patch" => {
            "pre_curation_uploads" => uploaded_file
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
        instance_double(Work)
      end

      before do
        sign_in user
        work.save

        allow(Rails.logger).to receive(:error)
        allow(Work).to receive(:find).and_return(persisted)
        allow(persisted).to receive(:to_s).and_return(work.id)
        allow(persisted).to receive(:doi).and_return(work.doi)
        allow(persisted).to receive(:pre_curation_uploads).and_raise(StandardError, "test error")

        post :file_uploaded, params: params
      end

      it "does not update the work and renders an error messages" do
        expect(response).to redirect_to(work_file_upload_path(work))
        expect(controller.flash[:notice]).to eq("Failed to attach the file uploads for the work #{work.doi}: test error. Please contact rdss@princeton.edu for assistance.")
        expect(Rails.logger).to have_received(:error).with("Failed to attach the file uploads for the work #{work.doi}: test error")
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
        stub_s3
        get :show, params: { id: work.id }
        expect(response).to render_template("show")
      end
    end

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
        it "redirects to the Work show view" do
          stub_s3
          get :resolve_doi, params: { doi: work.doi[-9..] }
          expect(response).to redirect_to(work_path(work))
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
        it "redirects to the Work show view" do
          stub_s3
          get :resolve_ark, params: { ark: work.ark[-9..] }
          expect(response).to redirect_to(work_path(work))
        end
      end
    end

    describe "#validate" do
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
      it "handles aprovals" do
        work.complete_submission!(user)
        stub_datacite_doi
        sign_in curator
        post :approve, params: { id: work.id }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}"
        expect(work.reload).to be_approved
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
          error = work.work_activity.find { |activity| activity.activity_type == "DATACITE_ERROR" }
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

      context "a tombstoned work" do
        it "handles withdraw errors" do
          work.withdraw(user)
          work.remove!(user)
          sign_in user
          post :withdraw, params: { id: work.id }
          expect(response.status).to be 422
          expect(work.reload).to be_tombstone
          expect(assigns[:errors]).to eq(["Cannot Withdraw: Event 'withdraw' cannot transition from 'tombstone'."])
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

    it "posts a comment" do
      sign_in user
      post :add_comment, params: { id: work.id, "new-comment" => "hello world" }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"
    end
  end

  describe "#update" do
    let(:params) do
      {
        id: work.id,
        title_main: work.title,
        collection_id: collection.id,
        new_title_1: "the subtitle",
        new_title_type_1: "Subtitle",
        existing_title_count: "1",
        new_title_count: "1",
        given_name_1: "Toni",
        family_name_1: "Morrison",
        sequence_1: "1",
        given_name_2: "Sonia",
        family_name_2: "Sotomayor",
        sequence_2: "1",
        orcid_2: "1234-1234-1234-1234",
        creator_count: "1",
        new_creator_count: "1",
        rights_identifier: "CC BY",
        description: "a new description"
      }
    end

    context "when authenticated" do
      context "when requesting a HTML representation" do
        let(:format) { :html }

        context "when the update succeeds" do
          before do
            sign_in user
            patch :update, params: params
          end

          it "redirects to the show page" do
            expect(response.code).to eq("302")
            expect(response).to redirect_to(work_path(work))
          end
        end

        context "a submitter trying to update the curator conrolled fields" do
          before do
            sign_in user
            new_params = params.merge(doi: "new-doi")
                               .merge(ark: "new-ark")
                               .merge(collection_tags: "new-colletion-tags")
            patch :update, params: new_params
          end

          it "does not update the curator controlled fields" do
            original_doi = work.doi
            original_ark = work.ark
            original_collection_tags = work.resource.collection_tags
            expect(work.reload.doi).to eq(original_doi)
            expect(work.ark).to eq(original_ark)
            expect(work.resource.collection_tags).to eq(original_collection_tags)
          end
        end

        context "a collection admin trying to update curator controlled fields" do
          let(:user) { FactoryBot.create :research_data_moderator }
          before do
            sign_in user
            new_params = params.merge(doi: "new-doi")
                               .merge(ark: "new-ark")
                               .merge(collection_tags: "new-colletion-tag1, new-collection-tag2")
                               .merge(resource_type: "digitized video")
                               .merge(resource_type_general: Datacite::Mapping::ResourceTypeGeneral::AUDIOVISUAL.key)

            patch :update, params: new_params
          end

          it "updates the curator controlled fields", mock_ezid_api: true do
            expect(work.reload.doi).to eq("new-doi")
            expect(work.ark).to eq("new-ark")
            expect(work.resource.collection_tags).to eq(["new-colletion-tag1", "new-collection-tag2"])
            expect(work.resource_type).to eq("digitized video")
            expect(work.resource_type_general.to_sym).to eq(::Datacite::Mapping::ResourceTypeGeneral::AUDIOVISUAL.key)
          end
        end

        context "when the update fails" do
          before do
            sign_in user
            allow(Work).to receive(:find).and_return(work)
            allow(work).to receive(:update).and_return(false)
            patch :update, params: params
          end

          it "renders the edit view with a 422 response status code" do
            expect(response.code).to eq("422")
            expect(response).to render_template(:edit)
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
      let(:new_params) { params.merge(doi: "new-doi").merge(ark: "new-ark").merge(collection_tags: "new-colletion-tag1, new-collection-tag2") }

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
          expect(work.ark).to eq("new-ark")
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
          expect(work.ark).to eq("new-ark")
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
end
