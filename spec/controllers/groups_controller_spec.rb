# frozen_string_literal: true
require "rails_helper"

RSpec.describe GroupsController do
  before do
    Group.create_defaults
  end

  let(:admin_user) { FactoryBot.create :super_admin_user }
  let(:user_no_edit) { User.new_for_uid("user2") }
  let(:group) { Group.where(code: "RD").first }

  it "renders the list page" do
    sign_in user_no_edit
    get :index
    expect(response).to render_template("index")
  end

  it "renders the edit page for admin users" do
    sign_in admin_user
    get :edit, params: { id: group.id }
    expect(response).to render_template("edit")
  end

  it "prevents user with no edit from editing" do
    sign_in user_no_edit
    get :edit, params: { id: group.id }
    expect(response.status).to eq 302
    expect(response.location).to eq "http://test.host/groups"
  end

  describe "#add_admin" do
    it "adds an administrator" do
      sign_in admin_user
      post :add_admin, params: { id: group.id, uid: "admin2" }
      expect(response.status).to eq 200

      # Detects that it has already been added when called for the same user
      post :add_admin, params: { id: group.id, uid: "admin2" }
      expect(response.status).to eq 400
    end

    it "prevents user with no edit from adding administrators" do
      sign_in user_no_edit
      post :add_admin, params: { id: group.id, uid: "admin2" }
      expect(response.status).to eq 401
    end
  end

  describe "#update" do
    it "performs an update" do
      params = {
        "group" => {
          "title" => "updated title",
          "description" => "updated description"
        },
        "commit" => "Update Dataset",
        "controller" => "groups",
        "action" => "update",
        "id" => group.id
      }
      sign_in admin_user
      post :update, params: params
      expect(response.status).to eq 302
      expect(response.location).to eq "http://test.host/groups/#{group.id}"
    end

    it "prevents user with no edit access from updating a group" do
      params = {
        "group" => {
          "title" => "updated title",
          "description" => "updated description"
        },
        "commit" => "Update Dataset",
        "controller" => "groups",
        "action" => "update",
        "id" => group.id
      }
      sign_in user_no_edit
      post :update, params: params
      expect(response.status).to eq 302
      expect(response.location).to eq "http://test.host/groups"
    end

    context "when an update request uses invalid parameters" do
      it "renders the Edit View with a 422 response" do
        params = {
          "group" => {
            "title" => nil,
            "description" => "updated description"
          },
          "commit" => "Update Dataset",
          "controller" => "groups",
          "action" => "update",
          "id" => group.id
        }
        sign_in admin_user
        post :update, params: params
        expect(response.status).to eq 422
        expect(response).to render_template("edit")
      end

      context "when the request is of the JSON content type" do
        it "renders the Edit View with a 422 response" do
          params = {
            "group" => {
              "title" => nil,
              "description" => "updated description"
            },
            "commit" => "Update Dataset",
            "controller" => "groups",
            "action" => "update",
            "id" => group.id
          }
          sign_in admin_user
          post :update, params: params, format: :json
          expect(response.status).to eq 422
          expect(response.content_type).to eq("application/json; charset=utf-8")
          json_body = JSON.parse(response.body)
          expect(json_body).to include("base" => ["Title cannot be empty"])
        end
      end
    end
  end

  describe "#add_submitter" do
    let(:non_default_group) { FactoryBot.create :group }
    it "adds a submitter" do
      sign_in admin_user
      # Detects that the user already has submitter rights to the default group
      User.new_for_uid("submit2")
      post :add_submitter, params: { id: group.id, uid: "submit2" }
      expect(response.status).to eq 400

      post :add_submitter, params: { id: non_default_group.id, uid: "submit2" }
      expect(response.status).to eq 200

      # Detects that it has already been added when called for the same user
      post :add_submitter, params: { id: non_default_group.id, uid: "submit2" }
      expect(response.status).to eq 400
    end

    it "prevents user with no edit from adding submitters" do
      sign_in user_no_edit
      post :add_submitter, params: { id: group.id, uid: "submit2" }
      expect(response.status).to eq 401
    end
  end

  describe "#delete_user_from_group" do
    it "removes a submitter" do
      user = User.new_for_uid("submit3")
      user.add_role :submitter, group
      expect(user.reload.has_role?(:submitter, group)).to be_truthy
      sign_in admin_user
      post :delete_user_from_group, params: { id: group.id, uid: "submit3" }
      expect(response.status).to eq 200
      expect(user.reload.has_role?(:submitter, group)).to be_falsey
    end

    it "removes an administrator" do
      user = User.new_for_uid("admin2")
      user.add_role :group_admin, group
      sign_in admin_user
      post :delete_user_from_group, params: { id: group.id, uid: "admin2" }
      expect(response.status).to eq 200

      # but don't allow to remove the current user
      post :delete_user_from_group, params: { id: group.id, uid: admin_user.uid }
      expect(response.status).to eq 400
    end

    it "fails for an unknown user" do
      sign_in admin_user
      post :delete_user_from_group, params: { id: group.id, uid: "unknown" }
      expect(response.status).to eq 400
    end

    it "prevents user with no edit from removing users" do
      sign_in user_no_edit
      post :delete_user_from_group, params: { id: group.id, uid: "submit2" }
      expect(response.status).to eq 401
    end
  end
end
