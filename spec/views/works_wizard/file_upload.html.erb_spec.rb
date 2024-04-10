# frozen_string_literal: true
require "rails_helper"

describe "works_wizard/file_upload.html.erb" do
  let(:user) { FactoryBot.create(:user) }

  before do
    Group.create_defaults
    user
    file_list_response = File.read(Rails.root.join("spec", "fixtures", "s3_list_bucket_result.xml"))
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, /https\:\/\/example-bucket.s3.amazonaws.com\/\?list-type/).
      to_return(status: 200, body: file_list_response, headers: {})
  end

  let(:work) { FactoryBot.create :draft_work }
  let(:work_decorator) { WorkDecorator.new(work, user)}

  it "supports multiple file uploads" do
    assign(:work, work)
    assign(:work_decorator, work_decorator)

    render

    expect(rendered).to include('<div id="file-upload-area">')
  end
end
