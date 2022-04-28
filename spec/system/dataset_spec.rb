# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating datasets", mock_ezid_api: true do
  # Notice that we manually create a user for this test (rather the one from FactoryBot)
  # because we need to make sure the user also has a list of collections where they can
  # submit datasets (UserCollection table) and the FactoryBot stub does not account for
  # that where as creating a user via `User.from_cas()` does.
  let(:user) do
    hash = OmniAuth::AuthHash.new(provider: "cas", uid: "who", extra: { mail: "who@princeton.edu", departmentnumber: "31000" })
    User.from_cas(hash)
  end

  it "Creates ARK when a new dataset is saved", js: true do
    sign_in user
    visit new_dataset_path
    expect(page).to have_content "ARK"
    click_on "Update Dataset"
    expect(page).to have_content "ARK"
    expect(page).to have_content Dataset.last.ark
  end
end
