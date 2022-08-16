# frozen_string_literal: true
require "rails_helper"

describe "works/file_upload.html.erb", mock_ezid_api: true do
  let(:collection) { Collection.first }
  let(:user) { FactoryBot.create(:user) }

  before do
    Collection.create_defaults
    user
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  let(:resource) { FactoryBot.build :resource }
  let(:work) do
    Work.create_dataset(user.id, collection.id, resource)
  end

  it "supports multiple file uploads" do
    assign(:work, work)

    render

    expect(rendered).to include("<input multiple=\"multiple\" type=\"file\"")
  end
end
