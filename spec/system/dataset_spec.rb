# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating datasets" do
  # Notice that we manually create a user for this test (rather the one from FactoryBot)
  # because we need to make sure the user also has a list of collections where they can
  # submit datasets (UserCollection table) and the FactoryBot stub does not account for
  # that where as creating a user via `User.from_cas()` does.
  let(:user) do
    hash = OmniAuth::AuthHash.new(provider: "cas", uid: "who", extra: { mail: "who@princeton.edu", departmentnumber: "31000" })
    User.from_cas(hash)
  end
  let(:identifier) { double(Ezid::Identifier) }
  let(:ezid_metadata_values) do
    {
      "_updated" => "1611860047",
      "_target" => "http://arks.princeton.edu/ark:/88435/dsp01zc77st047",
      "_profile" => "erc",
      "_export" => "yes",
      "_owner" => "pudiglib",
      "_ownergroup" => "pudiglib",
      "_created" => "1611860047",
      "_status" => "public"
    }
  end
  let(:ezid_metadata) do
    Ezid::Metadata.new(ezid_metadata_values)
  end
  let(:ezid) { "ark:/88435/dsp01zc77st047" }

  before do
    # this is a work-around due to an issue with webmock
    allow(Ezid::Identifier).to receive(:find).and_return(identifier)

    allow(identifier).to receive(:metadata).and_return(ezid_metadata)
    allow(identifier).to receive(:id).and_return(ezid)
    allow(identifier).to receive(:modify)
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
