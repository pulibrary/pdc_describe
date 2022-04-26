# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatasetsController, mock_ezid_api: true do
  before do
    Collection.create_defaults
    user
  end
  let(:user) { FactoryBot.create(:user) }
  let(:ds) { Dataset.create_skeleton("test dataset", user.id, Collection.first.id) }
  let(:ezid) { ds.ark }

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
          "title" => "test dataset updated",
          "collection_id" => ds.work.collection.id,
          "work_id" => ds.work.id,
          "ark" => ds.ark
        },
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
  end
end
