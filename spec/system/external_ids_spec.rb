# frozen_string_literal: true
require "rails_helper"

RSpec.describe "External Identifiers", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:princeton_submitter) }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    # Make the screen larger so the save button is alway on screen.  This avoids random `Element is not clickable` errors
    page.driver.browser.manage.window.resize_to(2000, 2000)
  end

  it "Mints a DOI, but does not mint an ark at any point in the wizard proccess" do
    sign_in user
    visit user_path(user)
    click_on "Submit New"
    fill_in "title_main", with: "test title"

    fill_in "given_name_1", with: "Sally"
    fill_in "family_name_1", with: "Smith"
    click_on "Create New"
    fill_in "description", with: "test description"
    find("#rights_identifier").find(:xpath, "option[2]").select_option
    click_on "Save Work"
    click_on "Continue"
    click_on "Continue"
    click_on "Complete"

    expect(page).to have_content "awaiting_approval"
    expect(Ezid::Identifier).not_to have_received(:mint)
    expect(a_request(:post, "https://api.datacite.org/dois")).to have_been_made
  end

  it "Mints a DOI, but does not mint an ark at any point in the non wizard proccess" do
    sign_in user
    visit user_path(user)
    click_on(user.uid)
    click_on "Create Dataset"
    fill_in "title_main", with: "test title"
    fill_in "description", with: "test description"
    fill_in "given_name_1", with: "Sally"
    fill_in "family_name_1", with: "Smith"
    find("#rights_identifier").find(:xpath, "option[2]").select_option
    click_on "Create"
    click_on "Complete"

    expect(page).to have_content "awaiting_approval"
    expect(Ezid::Identifier).not_to have_received(:mint)
    expect(a_request(:post, "https://api.datacite.org/dois")).to have_been_made
  end
end
