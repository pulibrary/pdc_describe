# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatasetsController do
  before { Collection.create_defaults }
  let(:user) { FactoryBot.create(:user) }

  context "valid user login" do
    it "handles the index page" do
      sign_in user
      get :index
      expect(response).to render_template("index")
    end

    it "handles the show page" do
      ds = Dataset.create_skeleton("test dataset", user.id, Collection.first.id)
      sign_in user
      get :show, params: { id: ds.id }
      expect(response).to render_template("show")
    end

    it "handles the dashboard page" do
      sign_in user
      get :dashboard
      expect(response).to render_template("dashboard")
    end

    it "renders the edit page when creating a new dataset" do
      sign_in user
      post :new
      expect(response).to render_template("edit")
    end

    it "renders the edit page on edit" do
      ds = Dataset.create_skeleton("test dataset", user.id, Collection.first.id)
      sign_in user
      get :edit, params: { id: ds.id }
      expect(response).to render_template("edit")
    end

    it "handles the update page" do
      ds = Dataset.create_skeleton("test dataset", user.id, Collection.first.id)
      params = {
        "dataset" => {
          "title" => "test dataset updated",
          "collection_id" => ds.collection_id.to_s,
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
  end
end
