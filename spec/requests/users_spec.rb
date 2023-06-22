# frozen_string_literal: true
require "rails_helper"

RSpec.describe "/users", type: :request do
  # User. As you add validations to User, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) do
    {
      uid: FFaker::InternetSE.login_user_name,
      email: FFaker::InternetSE.email,
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

    context "when updating group notification settings" do
      let(:group1) { Group.plasma_laboratory }
      let(:group2) { Group.research_data }
      let(:updated_attributes1) do
        {
          groups_with_messaging: {
            group1.id => "1",
            group2.id => "1"
          }
        }
      end
      let(:updated_attributes2) do
        {
          groups_with_messaging: {
            group1.id => "0",
            group2.id => "0"
          }
        }
      end
      let(:user) do
        FactoryBot.create(:user)
      end

      before do
        Group.create_defaults
        user.add_role(:group_admin, group1)
        user.add_role(:group_admin, group2)
        user.save!
        user.reload

        sign_in(user)
        patch user_url(user), params: { user: updated_attributes1 }
        user.reload
      end

      it "updates the notification settings for multiple groups" do
        expect(user.messages_enabled_from?(group: group1)).to be true
        expect(user.messages_enabled_from?(group: group2)).to be true

        patch user_url(user), params: { user: updated_attributes2 }
        user.reload

        expect(user.messages_enabled_from?(group: group1)).to be false
        expect(user.messages_enabled_from?(group: group2)).to be false
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
