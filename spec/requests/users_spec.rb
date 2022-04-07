# frozen_string_literal: true
require "rails_helper"

RSpec.describe "/users", type: :request do
  # User. As you add validations to User, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) do
    {
      uid: FFaker::Internet.user_name,
      email: FFaker::Internet.email,
      provider: :cas
    }
  end

  let(:invalid_attributes) do
    {
      favorite_color: "blue"
    }
  end

  describe "GET /show" do
    it "will not show a user page unless the user is logged in" do
      user = User.create! valid_attributes
      get user_url(user)
      expect(response.code).to eq "302"
      redirect_location = response.header["Location"]
      expect(redirect_location).to eq "http://www.example.com/sign_in"
    end
  end

  # We do NOT allow the creation of arbitrary users. New users should only be created
  # via CAS authentication.
  describe "GET /new" do
    it "redirects to CAS" do
      get "/users/new"
      expect(response.code).to eq "302"
      redirect_location = response.header["Location"]
      expect(redirect_location).to eq "http://www.example.com/sign_in"
    end
  end

  describe "GET /edit" do
    it "redirects to CAS" do
      user = User.create! valid_attributes
      get edit_user_url(user)
      expect(response.code).to eq "302"
      redirect_location = response.header["Location"]
      expect(redirect_location).to eq "http://www.example.com/sign_in"
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        {
          orcid: "1234-5678-1234-5678"
        }
      end

      it "does not update the requested user when unauthenticated" do
        user = User.create! valid_attributes
        patch user_url(user), params: { user: new_attributes }
        user.reload
        expect(user.orcid).to be_nil
      end
    end

    context "with invalid parameters" do
      it "renders a successful response (i.e. to display the 'edit' template)" do
        user = User.create! valid_attributes
        patch user_url(user), params: { user: invalid_attributes }
        expect(response.code).to eq "302"
        redirect_location = response.header["Location"]
        expect(redirect_location).to eq "http://www.example.com/sign_in"
      end
    end
  end
end
