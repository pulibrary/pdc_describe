# frozen_string_literal: true
require "rails_helper"

RSpec.describe CollectionsController do
  before do
    Collection.create_defaults
  end

  let(:admin_user) { User.new_for_uid("fake1") }
  let(:user_no_edit) { User.new_for_uid("user2") }
  let(:rd_collection) { Collection.where(code: "RD").first }

  it "renders the list page" do
    sign_in user_no_edit
    get :index
    expect(response).to render_template("index")
  end

  it "renders the edit page for admin users" do
    sign_in admin_user
    get :edit, params: { id: rd_collection.id }
    expect(response).to render_template("edit")
  end

  it "prevents user with no edit from editting" do
    sign_in user_no_edit
    get :edit, params: { id: rd_collection.id }
    expect(response.status).to eq 302
    expect(response.location).to eq "http://test.host/collections"
  end

  describe "#add_submitter" do
    it "adds an administrator" do
      sign_in admin_user
      post :add_admin, params: { id: rd_collection.id, uid: "admin2" }
      expect(response.status).to eq 200

      # Detects that it has already been added when called for the same user
      post :add_admin, params: { id: rd_collection.id, uid: "admin2" }
      expect(response.status).to eq 400
    end

    it "prevents user with no edit from adding administrators" do
      sign_in user_no_edit
      post :add_admin, params: { id: rd_collection.id, uid: "admin2" }
      expect(response.status).to eq 401
    end
  end

  describe "#add_submitter" do
    it "adds a submitter" do
      sign_in admin_user
      post :add_submitter, params: { id: rd_collection.id, uid: "submit2" }
      expect(response.status).to eq 200

      # Detects that it has already been added when called for the same user
      post :add_submitter, params: { id: rd_collection.id, uid: "submit2" }
      expect(response.status).to eq 400
    end

    it "prevents user with no edit from adding submitters" do
      sign_in user_no_edit
      post :add_submitter, params: { id: rd_collection.id, uid: "submit2" }
      expect(response.status).to eq 401
    end
  end
end
