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

    it "shows user fields", js: true do
      visit edit_user_path(user_admin)
      expect(page).to have_field :user_email
      expect(page).to have_field :user_uid
      expect(page).to have_field :user_default_group_id
    end

    it "allows to change other users' default group" do
      visit edit_user_path(user)
      expect(user.default_group.title).to eq Group.research_data.title
      select Group.plasma_laboratory.title, from: :user_default_group_id
      click_on "Save"
      user.reload
      expect(user.default_group.title).to eq Group.plasma_laboratory.title
    end
  end

  describe "Non-admin users" do
    let(:user) { FactoryBot.create :princeton_submitter }

    before { sign_in user }

    it "allows user to change their email", js: true do
      visit edit_user_path(user)
      fill_in "user_email", with: "an-updated@emai.com"
      click_on "Save"
      user.reload
      expect(user.email).to eq "an-updated@emai.com"
    end

    it "does not allow user to change their default group", js: true do
      visit edit_user_path(user)
      expect(page.html.include?("user_default_group_id")).to be false
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
      expect(page).to have_checked_field "user_email_messages_enabled"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}"
      expect(page).to have_checked_field "group_messaging_#{rd_group.id}"
      expect(page).not_to have_field "group_messaging_#{random_group.id}"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_Spherical Torus"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_Advanced Projects"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_ITER and Tokamaks"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_Theory"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_NSTX-U"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_NSTX"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_Discovery Plasma Science"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_Theory and Computation"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_Stellarators"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_PPPL Collaborations"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_MAST-U"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_Other Projects"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_System Studies"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_Applied Materials and Sustainability Sciences"
      uncheck "group_messaging_#{pppl_group.id}"
      click_on "Update"
      visit edit_user_path(user)
      expect(page).to have_checked_field "user_email_messages_enabled"
      expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}"
      expect(page).to have_checked_field "group_messaging_#{rd_group.id}"
      expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}_MAST-U"
      expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}_Other Projects"
      check "group_messaging_#{pppl_group.id}_MAST-U"
      click_on "Update"
      visit edit_user_path(user)
      expect(page).to have_checked_field "user_email_messages_enabled"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}"
      expect(page).to have_checked_field "group_messaging_#{rd_group.id}"
      expect(page).to have_checked_field "group_messaging_#{pppl_group.id}_MAST-U"
      expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}_Other Projects"
      uncheck "user_email_messages_enabled"
      click_on "Update"
      visit edit_user_path(user)
      expect(page).to have_unchecked_field "user_email_messages_enabled"
      expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}"
      expect(page).to have_unchecked_field "group_messaging_#{rd_group.id}"
      expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}_MAST-U"
      expect(page).to have_unchecked_field "group_messaging_#{pppl_group.id}_Other Projects"
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
