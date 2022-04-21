# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Editing users" do
  describe "Admin users can edit other users data" do
    before { sign_in user_admin }

    let(:user) { FactoryBot.create :user }
    let(:user_admin) { FactoryBot.create :admin_user }
    let(:orcid) { "1234-5678-1234-5678" }

    it "allows an admin to edit other users ORCID", js: true do
      visit user_path(user)
      expect(page).to have_content user.uid
      click_on "Edit"
      expect(page).to have_content "Editing User"
      fill_in "user_orcid", with: orcid
      click_on "Save"
      expect(page).to have_content "ORCiD: #{orcid}"
    end
  end

  describe "Non-admin users cannot edit others people data" do
    before { sign_in user }

    let(:user) { FactoryBot.create :user }
    let(:user_other) { FactoryBot.create :user }
    let(:orcid) { "1234-5678-1234-5678" }

    it "allows an admin to edit other users ORCID", js: true do
      visit user_path(user_other)
      expect(page).to have_content user_other.uid
      expect(page).to_not have_content "Edit"
    end
  end
end
