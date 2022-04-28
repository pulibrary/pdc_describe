# frozen_string_literal: true
require "rails_helper"

RSpec.describe CollectionsController do
  before do
    Collection.create_defaults
  end

  let(:admin_user) { User.new_for_uid("fake1") }
  let(:user_no_edit) { User.new_for_uid("user2") }
  let(:collection) { Collection.where(code: "RD").first }

  it "renders the list page" do
    sign_in user_no_edit
    get :index
    expect(response).to render_template("index")
  end

  it "renders the edit page for admin users" do
    sign_in admin_user
    get :edit, params: { id: collection.id }
    expect(response).to render_template("edit")
  end

  it "prevents user with no edit from editting" do
    sign_in user_no_edit
    get :edit, params: { id: collection.id }
    expect(response.status).to eq 302
    expect(response.location).to eq "http://test.host/collections"
  end

  describe "#add_admin" do
    it "adds an administrator" do
      sign_in admin_user
      post :add_admin, params: { id: collection.id, uid: "admin2" }
      expect(response.status).to eq 200

      # Detects that it has already been added when called for the same user
      post :add_admin, params: { id: collection.id, uid: "admin2" }
      expect(response.status).to eq 400
    end

    it "prevents user with no edit from adding administrators" do
      sign_in user_no_edit
      post :add_admin, params: { id: collection.id, uid: "admin2" }
      expect(response.status).to eq 401
    end
  end

  describe "#update" do
    it "performs an update" do
      params = {
        "collection" => {
          "title" => "updated title",
          "description" => "updated description"
        },
        "commit" => "Update Dataset",
        "controller" => "collections",
        "action" => "update",
        "id" => collection.id
      }
      sign_in admin_user
      post :update, params: params
      expect(response.status).to eq 302
      expect(response.location).to eq "http://test.host/collections/#{collection.id}"
    end

    it "prevents user with no edit access from updating a collection" do
      params = {
        "collection" => {
          "title" => "updated title",
          "description" => "updated description"
        },
        "commit" => "Update Dataset",
        "controller" => "collections",
        "action" => "update",
        "id" => collection.id
      }
      sign_in user_no_edit
      post :update, params: params
      expect(response.status).to eq 302
      expect(response.location).to eq "http://test.host/collections"
    end
  end

  describe "#add_submitter" do
    it "adds a submitter" do
      sign_in admin_user
      post :add_submitter, params: { id: collection.id, uid: "submit2" }
      expect(response.status).to eq 200

      # Detects that it has already been added when called for the same user
      post :add_submitter, params: { id: collection.id, uid: "submit2" }
      expect(response.status).to eq 400
    end

    it "prevents user with no edit from adding submitters" do
      sign_in user_no_edit
      post :add_submitter, params: { id: collection.id, uid: "submit2" }
      expect(response.status).to eq 401
    end
  end

  describe "#delete_user_from_collection" do
    it "removes a submitter" do
      user = User.new_for_uid("submit3")
      UserCollection.add_submitter(user.id, collection.id)
      sign_in admin_user
      post :delete_user_from_collection, params: { id: collection.id, uid: "submit3" }
      expect(response.status).to eq 200
    end

    it "removes an administrator" do
      user = User.new_for_uid("admin2")
      UserCollection.add_admin(user.id, collection.id)
      sign_in admin_user
      post :delete_user_from_collection, params: { id: collection.id, uid: "admin2" }
      expect(response.status).to eq 200

      # but don't allow to remove the current user
      post :delete_user_from_collection, params: { id: collection.id, uid: admin_user.uid }
      expect(response.status).to eq 400
    end

    it "prevents user with no edit from removing users" do
      sign_in user_no_edit
      post :delete_user_from_collection, params: { id: collection.id, uid: "submit2" }
      expect(response.status).to eq 401
    end
  end
end
