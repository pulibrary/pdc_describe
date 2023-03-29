# frozen_string_literal: true
require "rails_helper"

RSpec.describe "External Identifiers", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:princeton_submitter) }
  let(:research_data_moderator) { FactoryBot.create :research_data_moderator }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_s3
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
    select "GNU General Public License", from: "rights_identifier"
    click_on "Save Work"
    click_on "Continue"
    click_on "Continue"
    click_on "Continue"
    click_on "Complete"

    expect(page).to have_content "awaiting_approval"
    expect(Ezid::Identifier).not_to have_received(:mint)
    expect(a_request(:post, "https://api.datacite.org/dois")).to have_been_made
  end

  it "Mints a DOI, but does not mint an ark at any point in the non wizard proccess" do
    sign_in research_data_moderator
    visit user_path(research_data_moderator)
    click_on(research_data_moderator.uid)
    click_on "Create Dataset"
    fill_in "title_main", with: "test title"
    fill_in "description", with: "test description"
    fill_in "given_name_1", with: "Sally"
    fill_in "family_name_1", with: "Smith"
    select "GNU General Public License", from: "rights_identifier"
    click_on "Create"
    click_on "Complete"

    expect(page).to have_content "awaiting_approval"
    expect(Ezid::Identifier).not_to have_received(:mint)
    expect(a_request(:post, "https://api.datacite.org/dois")).to have_been_made
  end
end
