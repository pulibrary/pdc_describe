# frozen_string_literal: true

require "rails_helper"

describe "features", type: :system, js: true do
  it "flip flop doesn't show for un logged in user" do
    visit "/features"
    expect(page).to have_content("Log in")
  end

  it "flip flop doesn't show for a regular user" do
    user = FactoryBot.create(:user)
    sign_in user
    visit "/features"
    expect(page).not_to have_content("Create a dataset")
  end
end
