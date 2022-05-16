# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatasetsController, mock_ezid_api: true do
  before do
    Collection.create_defaults
    user
  end
  let(:user) { FactoryBot.create(:user) }
  let(:collection) { Collection.first }
  let(:ds) { Dataset.create_skeleton("test dataset", user.id, collection.id) }
  let(:ezid) { ds.ark }
  let(:work) { ds.work }

  context "valid user login" do
    it "handles the index page" do
      sign_in user
      get :index
      expect(response).to render_template("index")
    end

    it "handles the show page" do
      sign_in user
      get :show, params: { id: ds.id }
      expect(response).to render_template("show")
    end

    it "renders the edit page when creating a new dataset" do
      sign_in user
      post :new
      expect(response.status).to be 302
      expect(response.location.start_with?("http://test.host/datasets/")).to be true
    end

    it "renders the edit page on edit" do
      sign_in user
      get :edit, params: { id: ds.id }
      expect(response).to render_template("edit")
    end

    it "handles the update page" do
      params = {
        "dataset" => {
          "work_id" => ds.work.id
        },
        "title" => "test dataset updated",
        "collection_id" => ds.work.collection.id,
        "commit" => "Update Dataset",
        "controller" => "datasets",
        "action" => "update",
        "id" => ds.id.to_s
      }
      sign_in user
      post :update, params: params
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/datasets/#{ds.id}"
    end

    it "handles aprovals" do
      sign_in user
      post :approve, params: { id: ds.id }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/datasets/#{ds.id}"
    end

    it "handles withdraw" do
      sign_in user
      post :withdraw, params: { id: ds.id }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/datasets/#{ds.id}"
    end

    it "handles resubmit" do
      sign_in user
      post :resubmit, params: { id: ds.id }
      expect(response.status).to be 302
      expect(response.location).to eq "http://test.host/datasets/#{ds.id}"
    end

    it "handles the show page" do
      sign_in user
      get :datacite, params: { id: ds.id }
      expect(response.body.start_with?('<?xml version="1.0"?>')).to be true
    end
  end

  describe "#update" do
    let(:params) do
      {
        id: ds.id,
        title: ds.title,
        collection_id: collection.id,
        dataset: {
          id: ds.id,
          work_id: work.id,
          format: format
        },
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
            allow_any_instance_of(Dataset).to receive(:update).and_return(false)
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
            allow_any_instance_of(Dataset).to receive(:update).and_return(false)
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
