# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Add an ORCiD" do
  before { sign_in user }

  describe "When the user does not have an ORCiD yet" do
    let(:user) { FactoryBot.create :princeton_submitter }
    let(:orcid) { "1234-5678-1234-5678" }

    it "takes a user to their homepage after login", js: true do
      visit user_path(user)
      expect(page).to have_content "Welcome"
      expect(page).to have_content "You do not have an ORCID iD on file."
      click_on "Add one"
      expect(page).to have_content "My Profile Settings"
      fill_in "user_orcid", with: orcid
      click_on "Save"
      expect(page).to_not have_content "You do not have an ORCID iD on file."
    end
  end
end
