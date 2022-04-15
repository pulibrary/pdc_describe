# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatasetsController do
  before { Collection.create_defaults }
  let(:user) { FactoryBot.create(:user) }

  context "valid user login" do
    it "handles the index page" do
      sign_in user
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template("index")
    end

    it "handles the show page" do
      ds = Dataset.create_skeleton("test dataset", user.id, Collection.first.id)
      sign_in user
      get :show, params: { id: ds.id }
      expect(response.status).to eq(200)
      expect(response).to render_template("show")
    end

    it "renders the edit page when creating a new dataset" do
      sign_in user
      post :new
      expect(response.status).to eq(200)
      expect(response).to render_template("edit")
    end
  end
end
