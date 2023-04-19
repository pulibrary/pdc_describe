# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Editing collections" do
  before { Group.create_defaults }

  let(:user) { FactoryBot.create :princeton_submitter }
  let(:super_admin_user) { FactoryBot.create :super_admin_user }
  let(:collection) { FactoryBot.create :group }
  let(:collection_other) { Group.second }

  let(:collection_admin_user) { FactoryBot.create :user, groups_to_admin: [collection, Group.research_data] }

  it "allows super admin to edit collections", js: true do
    sign_in super_admin_user
    visit collection_path(collection)
    click_on "Edit"
    expect(page).to have_content "Editing Group"
  end

  it "does not allow a regular user to edit a collection nor view the list of datasets for the collection", js: true do
    sign_in user
    visit collection_path(collection)
    expect(page).to have_content collection.title
    expect(page).to_not have_content "Edit"
    expect(page).to_not have_css(".dataset-section")
  end

  it "allows a collection admin to edit their collection", js: true do
    sign_in collection_admin_user
    visit collection_path(collection)
    click_on "Edit"
    expect(page).to have_content "Editing Group"
  end

  it "allows a collection admin to add a submitter to the collection", js: true do
    sign_in collection_admin_user
    visit edit_collection_path(collection)
    fill_in "submitter-uid-to-add", with: "submiter123"
    click_on "Add Submitter"
    expect(page).to have_content "submiter123"
    expect(page).not_to have_content "User has already been added"
  end

  it "allows a collection admin to add a submitter to their defailt collection without error only when the user is first created", js: true do
    sign_in collection_admin_user
    visit edit_collection_path(Group.research_data)
    fill_in "submitter-uid-to-add", with: "submiter123"
    click_on "Add Submitter"
    expect(page).to have_content "submiter123"
    expect(page).not_to have_content "User has already been added"
    fill_in "submitter-uid-to-add", with: "submiter123"
    click_on "Add Submitter"
    expect(page).to have_content "User has already been added"
  end

  it "allows a curator to add another curator to the collection", js: true do
    sign_in collection_admin_user
    visit edit_collection_path(collection)
    fill_in "admin-uid-to-add", with: "admin123"
    click_on "Add Moderator"
    expect(page).to have_content "admin123"
  end

  it "does not a collection admin to edit another collection", js: true do
    sign_in collection_admin_user
    visit collection_path(collection_other)
    expect(page).to have_content collection_other.title
    expect(page).to_not have_content "Edit"
  end

  it "display super admins", js: true do
    super_admin_user
    sign_in user
    visit collection_path(collection)
    expect(page).to have_content super_admin_user.uid
  end
end
