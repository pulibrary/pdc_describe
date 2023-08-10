# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Editing users", type: :system do
  describe "Admin users can edit other users data" do
    before { sign_in user_admin }

    let(:user) { FactoryBot.create :princeton_submitter }
    let(:user_admin) { FactoryBot.create :super_admin_user }
    let(:orcid) { "1234-5678-1234-5678" }

    it "allows an admin to edit other users ORCID", js: true do
      visit user_path(user)
      expect(page).to have_content user.given_name
      click_on "Edit"
      expect(page).to have_content "My Profile Settings"
      fill_in "user_orcid", with: orcid
      click_on "Save"
    end
  end

  describe "Non-admin users cannot access others people data" do
    before { sign_in user }

    let(:user) { FactoryBot.create :princeton_submitter }
    let(:user_other) { FactoryBot.create :user }
    let(:orcid) { "1234-5678-1234-5678" }

    it "renders a 403 forbidden page" do
      visit user_path(user_other)
      expect(page.status_code).to eq(403)
    end
  end

  describe "Allows a user to edit which collections send emails", js: true do
    let(:user) { FactoryBot.create :princeton_submitter }
    let(:pppl_group) { Group.plasma_laboratory }
    let(:rd_group) { Group.research_data }
    let(:random_group) { FactoryBot.create(:group) }

    before do
      sign_in user
      user.add_role(:submitter, pppl_group)
      random_group # ensure the group exists
    end

    it "shows the form" do
      visit edit_user_path(user)
      expect(page).to have_field("user_given_name", with: user.given_name)
      expect(page).to have_content "My Profile Settings"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}"
      expect(page).to have_checked_field "group_messaging_#{rd_group.id}"
      expect(page).not_to have_field "group_messaging_#{random_group.id}"
      uncheck "group_messaging_#{pppl_group.id}"
      click_on "Update"
      visit edit_user_path(user)
      expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}"
      expect(page).to have_checked_field "group_messaging_#{rd_group.id}"
    end

    context "User is super admin" do
      let(:user) { FactoryBot.create :super_admin_user }

      it "shows the form with all the collections and all the groups are checked" do
        visit edit_user_path(user)
        expect(page).to have_field("user_given_name", with: user.given_name)
        expect(page).to have_content "My Profile Settings"
        expect(page).to have_checked_field "group_messaging_#{pppl_group.id}"
        expect(page).to have_checked_field "group_messaging_#{rd_group.id}"
        expect(page).to have_checked_field "group_messaging_#{random_group.id}"
        uncheck "group_messaging_#{rd_group.id}"
        uncheck "group_messaging_#{pppl_group.id}"
        uncheck "group_messaging_#{random_group.id}"
        click_on "Update"
        visit edit_user_path(user)
        expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}"
        expect(page).to have_unchecked_field "group_messaging_#{rd_group.id}"
        expect(page).to have_unchecked_field "group_messaging_#{random_group.id}"
        check "group_messaging_#{rd_group.id}"
        check "group_messaging_#{random_group.id}"
        click_on "Update"
        visit edit_user_path(user)
        expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}"
        expect(page).to have_checked_field "group_messaging_#{rd_group.id}"
        expect(page).to have_checked_field "group_messaging_#{random_group.id}"
      end
    end
  end
end
