# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorksController, mock_ezid_api: true do
  before do
    Collection.create_defaults
    user
    stub_datacite(user: "foo", password: "bar", encoded_user: "Zm9vOmJhcg==", host: "api.datacite.org")
  end
  let(:user) { FactoryBot.create(:user) }
  let(:collection) { Collection.first }
  let(:work) do
    datacite_resource = PULDatacite::Resource.new
    datacite_resource.creators << PULDatacite::Creator.new_person("Harriet", "Tubman")
    Work.create_dataset("test dataset", user.id, collection.id, datacite_resource)
  end

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
      get :new_submission
      expect(response).to render_template("new_submission")
    end

    it "renders the edit page when creating a new dataset" do
      sign_in user
      post :new
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

    it "renders the complete page and saves the submission notes" do
      sign_in user
      post :completed, params: { id: work.id, submission_notes: "I need this processed ASAP" }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"
      expect(Work.find(work.id).submission_notes).to eq "I need this processed ASAP"
    end

    it "handles aprovals" do
      sign_in user
      post :approve, params: { id: work.id }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"
    end

    it "handles withdraw" do
      sign_in user
      post :withdraw, params: { id: work.id }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"
    end

    it "handles resubmit" do
      sign_in user
      post :resubmit, params: { id: work.id }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/works/#{work.id}"
    end

    it "handles the show page" do
      sign_in user
      get :datacite, params: { id: work.id }
      expect(response.body.start_with?('<?xml version="1.0"?>')).to be true
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
