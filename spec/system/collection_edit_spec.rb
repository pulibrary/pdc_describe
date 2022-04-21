# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Editing collections" do
  before { Collection.create_defaults }

  let(:user) { FactoryBot.create :user }
  let(:user_admin) { FactoryBot.create :admin_user }
  let(:collection) { Collection.first }

  it "allows super admin to edit collections", js: true do
    sign_in user_admin
    visit collection_path(collection)
    click_on "Edit"
    expect(page).to have_content "Editing Collection"
  end

  it "don't allow a regular user to edit a collection", js: true do
    sign_in user
    visit collection_path(collection)
    expect(page).to have_content collection.title
    expect(page).to_not have_content "Edit"
  end
end
