# frozen_string_literal: true
require "rails_helper"

describe "works_wizard/file_upload.html.erb" do
  let(:user) { FactoryBot.create(:user) }

  before do
    Group.create_defaults
    user
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  let(:work) { FactoryBot.create :draft_work }

  it "supports multiple file uploads" do
    assign(:work, work)

    render

    expect(rendered).to include("<input multiple=\"multiple\" type=\"file\"")
  end
end
