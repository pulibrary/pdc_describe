# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Add an ORCiD" do
  before do
    sign_in user
  end

  describe "When the user does not have an ORCiD yet" do
    let(:user) { FactoryBot.create :user }
    let(:orcid) { "1234-5678-1234-5678" }

    it "takes a user to their homepage after login", js: true do
      visit user_path(user)
      expect(page).to have_content "Welcome"
      expect(page).to have_content "You do not have an ORCiD on file."
      click_on "Edit"
      expect(page).to have_content "Editing User"
      fill_in "user_orcid", with: orcid
      click_on "Update User"
      expect(page).to have_content "Your ORCiD is #{orcid}"
    end
  end

  describe "When the user already has an ORCiD" do
    let(:orcid) { "1234-5678-1234-5678" }
    let(:valid_attributes) do
      {
        uid: FFaker::Internet.user_name,
        email: FFaker::Internet.email,
        provider: :cas,
        orcid: orcid
      }
    end
    let(:user) { User.create! valid_attributes }

    it "takes a user to their homepage after login", js: true do
      visit user_path(user)
      expect(page).to have_content "Welcome"
      expect(page).to have_content "Your ORCiD is #{orcid}"
    end
  end
end
