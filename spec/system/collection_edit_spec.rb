# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Editing collections" do
  before { Collection.create_defaults }

  let(:user) { FactoryBot.create :user }
  let(:super_admin_user) { User.new_for_uid("fake1") }
  let(:collection) { Collection.first }
  let(:collection_other) { Collection.second }

  # Notice that we manually create a user for this test because we need the
  # related data in UserCollection to make them collection administrators
  let(:collection_admin_user) do
    hash = OmniAuth::AuthHash.new(provider: "cas", uid: "who", extra: { mail: "who@princeton.edu", departmentnumber: "31000" })
    user = User.from_cas(hash)
    UserCollection.add_admin(user.id, collection.id)
    user
  end

  it "allows super admin to edit collections", js: true do
    sign_in super_admin_user
    visit collection_path(collection)
    click_on "Edit"
    expect(page).to have_content "Editing Collection"
  end

  it "does not allow a regular user to edit a collection", js: true do
    sign_in user
    visit collection_path(collection)
    expect(page).to have_content collection.title
    expect(page).to_not have_content "Edit"
  end

  it "allows a collection admin to edit their collection", js: true do
    sign_in collection_admin_user
    visit collection_path(collection)
    click_on "Edit"
    expect(page).to have_content "Editing Collection"
  end

  it "allows a collection admin to add a submitter to the collection", js: true do
    sign_in collection_admin_user
    visit collection_path(collection)
    fill_in "submitter-uid-to-add", with: "submiter123"
    click_on "Add Submitter"
    expect(page).to have_content "submiter123"
  end

  it "allows a collection admin to add an admin to the collection", js: true do
    sign_in collection_admin_user
    visit collection_path(collection)
    fill_in "admin-uid-to-add", with: "admin123"
    click_on "Add Administrator"
    expect(page).to have_content "admin123"
  end

  it "does not a collection admin to edit another collection", js: true do
    sign_in collection_admin_user
    visit collection_path(collection_other)
    expect(page).to have_content collection_other.title
    expect(page).to_not have_content "Edit"
  end

  it "display super admins", js: true do
    sign_in user
    visit collection_path(collection)
    expect(page).to have_content super_admin_user.uid
  end
end
