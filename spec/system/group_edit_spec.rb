# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Editing groups" do
  before { Group.create_defaults }

  let(:user) { FactoryBot.create :princeton_submitter }
  let(:super_admin_user) { FactoryBot.create :super_admin_user }
  let(:group) { FactoryBot.create :group }
  let(:group_other) { Group.second }

  let(:group_admin_user) { FactoryBot.create :user, groups_to_admin: [group, Group.research_data] }

  it "allows super admin to edit groups", js: true do
    sign_in super_admin_user
    visit group_path(group)
    click_on "Edit"
    expect(page).to have_content "Editing Group"
  end

  it "does not allow a regular user to edit a group nor view the list of datasets for the group", js: true do
    sign_in user
    visit group_path(group)
    expect(page).to have_content group.title
    expect(page).to_not have_content "Edit"
    expect(page).to_not have_css(".dataset-section")
  end

  it "allows a group admin to edit their group", js: true do
    sign_in group_admin_user
    visit group_path(group)
    click_on "Edit"
    expect(page).to have_content "Editing Group"
  end

  it "allows a group admin to add a submitter to the group", js: true do
    sign_in group_admin_user
    visit edit_group_path(group)
    fill_in "submitter-uid-to-add", with: "submitter123"
    click_on "Add Submitter"
    expect(page).to have_content "submitter123"
    expect(page).not_to have_content "User has already been added"
  end

  it "allows a group admin to add a submitter to their default group without error only when the user is first created", js: true do
    sign_in group_admin_user
    visit edit_group_path(Group.research_data)
    fill_in "submitter-uid-to-add", with: "submiter123"
    click_on "Add Submitter"
    expect(page).to have_content "submiter123"
    expect(page).not_to have_content "User has already been added"
    fill_in "submitter-uid-to-add", with: "submiter123"
    click_on "Add Submitter"
    expect(page).to have_content "User has already been added"
  end

  it "allows a group admin to add submitter and admin roles and delete only admin", js: true do
    sign_in group_admin_user
    visit edit_group_path(Group.research_data)
    fill_in "submitter-uid-to-add", with: "submiter123"
    click_on "Add Submitter"
    expect(page).to have_content "submiter123"
    expect(page).not_to have_content "User has already been added"
    fill_in "admin-uid-to-add", with: "submiter123"
    click_on "Add Moderator"
    within("#curator-list") do
      expect(page).to have_content "submiter123"
      expect(page).not_to have_content "User has already been added"
      find(".li-user-submiter123 .delete_icon").click
    end
    page.accept_alert
    within("#curator-list") do
      expect(page).not_to have_content "submiter123"
    end
    visit edit_group_path(Group.research_data)
    within("#submitter-list") do
      expect(page).to have_content "submiter123"
    end
  end

  it "allows a curator to add another curator to the group", js: true do
    sign_in group_admin_user
    visit edit_group_path(group)
    fill_in "admin-uid-to-add", with: "admin123"
    click_on "Add Moderator"
    expect(page).to have_content "admin123"
  end

  it "does not a group admin to edit another group", js: true do
    sign_in group_admin_user
    visit group_path(group_other)
    expect(page).to have_content group_other.title
    expect(page).to_not have_content "Edit"
  end

  it "display super admins", js: true do
    super_admin_user
    sign_in user
    visit group_path(group)
    expect(page).to have_content super_admin_user.uid
  end
end
