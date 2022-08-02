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

  let(:work) do
    datacite_resource = PULDatacite::Resource.new
    datacite_resource.creators << PULDatacite::Creator.new_person("Harriet", "Tubman")
    datacite_resource.description = "description of the test dataset"
    Work.create_dataset("test dataset", user.id, collection.id, datacite_resource)
  end

  it "supports multiple file uploads" do
    assign(:work, work)

    render

    expect(rendered).to include("<input multiple=\"multiple\" type=\"file\"")
  end
end
