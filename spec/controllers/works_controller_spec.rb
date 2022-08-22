# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorksController, mock_ezid_api: true do
  before do
    Collection.create_defaults
    user
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end
  let(:user) { FactoryBot.create(:user) }
  let(:curator) { FactoryBot.create(:user) }
  let(:collection) { Collection.first }
  let(:resource) { FactoryBot.build :resource }
  let(:work) { FactoryBot.create(:draft_work) }

  context "valid user login" do
    it "handles the index page" do
      sign_in user
      get :index
      expect(response).to render_template("index")
    end

    it "handles the show page" do
      stub_s3
      sign_in user
      get :show, params: { id: work.id }
      expect(response).to render_template("show")
    end

    it "renders the new submission wizard' step 0" do
      sign_in user
      get :new
      expect(response).to render_template("new_submission")
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

    it "renders the edit page on edit" do
      sign_in user
      get :edit, params: { id: work.id }
      expect(response).to render_template("edit")
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
        "creator_count" => "1"
      }
      sign_in user
      post :update, params: params
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"
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
      end
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
        "sequence_1" => "1",
        "given_name_2" => "Ada",
        "family_name_2" => "Lovelace",
        "sequence_2" => "2",
        "creator_count" => "2"
      }
      sign_in user
      post :update, params: params

      saved_work = Work.find(work.id)
      expect(saved_work.resource.creators[0].value).to eq "Smith, Jane"
      expect(saved_work.resource.creators[1].value).to eq "Lovelace, Ada"

      params_reordered = {
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
        "sequence_1" => "2",
        "given_name_2" => "Ada",
        "family_name_2" => "Lovelace",
        "sequence_2" => "1",
        "creator_count" => "2"
      }

      post :update, params: params_reordered
      reordered_work = Work.find(work.id)
      expect(reordered_work.resource.creators[0].value).to eq "Lovelace, Ada"
      expect(reordered_work.resource.creators[1].value).to eq "Smith, Jane"
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
          "deposit_uploads" => uploaded_file
        }
        sign_in user
        expect(work.deposit_uploads).to be_empty
        post :update, params: params

        saved_work = Work.find(work.id)

        expect(saved_work.deposit_uploads).not_to be_empty
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
          "deposit_uploads" => uploaded_files
        }
        sign_in user
        expect(work.deposit_uploads).to be_empty
        post :update, params: params

        saved_work = Work.find(work.id)

        expect(saved_work.deposit_uploads).not_to be_empty
      end
    end

    context "when only some file uploads are replaced for an existing Work with uploads" do
      let(:uploaded_file1) do
        fixture_file_upload("us_covid_2019.csv", "text/csv")
      end

      let(:uploaded_file2) do
        fixture_file_upload("us_covid_2020.csv", "text/csv")
      end

      let(:uploaded_files) do
        {
          "0" => uploaded_file2,
          "2" => uploaded_file2
        }
      end

      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      before do
        stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)

        work.deposit_uploads.attach(uploaded_file1)
        work.deposit_uploads.attach(uploaded_file1)
        work.deposit_uploads.attach(uploaded_file1)

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

        expect(saved_work.deposit_uploads).not_to be_empty
        expect(saved_work.deposit_uploads.length).to eq(3)

        expect(saved_work.deposit_uploads[0].blob.filename.to_s).to eq("us_covid_2019.csv")
        expect(saved_work.deposit_uploads[1].blob.filename.to_s).to eq("us_covid_2020.csv")
        expect(saved_work.deposit_uploads[2].blob.filename.to_s).to eq("us_covid_2020.csv")
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
            "deposit_uploads" => uploaded_file
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
        expect(reloaded.deposit_uploads).not_to be_empty
        expect(reloaded.deposit_uploads.first).to be_an(ActiveStorage::Attachment)
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
          expect(reloaded.deposit_uploads).to be_empty
        end
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

    describe "#completed" do
      it "saves the submission notes and renders the user dashboard" do
        sign_in user
        post :completed, params: { id: work.id, submission_notes: "I need this processed ASAP" }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/users/#{user.uid}"
        expect(Work.find(work.id).submission_notes).to eq "I need this processed ASAP"
      end

      context "an invalid work" do
        it "handles completion errors" do
          work.resource.description = nil
          work.save
          sign_in user
          post :completed, params: { id: work.id }
          expect(response.status).to be 422
          expect(work.reload).to be_draft
          expect(assigns[:errors]).to eq(["Cannot Complete submission: Event 'complete_submission' cannot transition from 'draft'. Failed callback(s): [:valid_to_submit]."])
        end
      end
    end

    describe "#approve" do
      it "handles aprovals" do
        sign_in user
        work.complete_submission!(user)
        post :approve, params: { id: work.id }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}"
        expect(work.reload).to be_approved
      end

      context "work not completed" do
        it "handles aproval errors" do
          sign_in user
          post :approve, params: { id: work.id }
          expect(response.status).to be 422
          expect(work.reload).to be_draft
          expect(assigns[:errors]).to eq(["Cannot Approve: Event 'approve' cannot transition from 'draft'."])
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

    it "handles the show page" do
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
        title: work.title,
        collection_id: collection.id,
        new_title_1: "the subtitle",
        new_title_type_1: "Subtitle",
        existing_title_count: "1",
        new_title_count: "1",
        given_name_1: "Toni",
        family_name_1: "Morrison",
        new_given_name_1: "Sonia",
        new_family_name_1: "Sotomayor",
        new_orcid_1: "1234-1234-1234-1234",
        existing_creator_count: "1",
        new_creator_count: "1"
      }
    end

    context "when authenticated" do
      context "when requesting a HTML representation" do
        let(:format) { :html }

        context "when the update fails" do
          before do
            sign_in user
            allow(Work).to receive(:find).and_return(work)
            allow_any_instance_of(Work).to receive(:update).and_return(false)
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
  end
end
