# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, mock_ezid_api: true do
  let(:user) { FactoryBot.create(:princeton_submitter) }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  it "Prevents empty title", js: true do
    sign_in user
    visit new_work_path
    fill_in "title_main", with: ""
    click_on "Create New"
    expect(page).to have_content "Must provide a title"
  end

  # this test depends of the fake ORCID server defined in spec/support/orcid_specs.rb
  it "Fills in the creator based on an ORCID ID", js: true do
    sign_in user
    visit new_work_path
    click_on "Add Another Creator"
    within("#creator_row_1") do
      fill_in "orcid_1", with: "0000-0000-1111-2222"
    end
    expect(page.find_by_id("given_name_1").value).to eq "Sally"
    expect(page.find_by_id("family_name_1").value).to eq "Smith"
  end

  it "Renders ORCID links for creators", js: true do
    stub_s3
    resource = FactoryBot.build(:resource, creators: [PDCMetadata::Creator.new_person("Harriet", "Tubman", "1234-5678-9012-3456")])
    work = FactoryBot.create(:draft_work, resource: resource)

    sign_in user
    visit work_path(work)
    expect(page.html.include?('<a href="https://orcid.org/1234-5678-9012-3456"')).to be true
  end

  it "Renders in wizard mode when requested", js: true do
    work = FactoryBot.create(:draft_work)

    sign_in user
    visit edit_work_path(work, wizard: true)
    expect(page.html.include?("By initiating this new submission, we have reserved a draft DOI for your use")).to be true
  end

  context "datacite record" do
    let(:work) { FactoryBot.create :draft_work }

    before do
      stub_s3
      sign_in user
    end

    it "Renders an xml serialization of the datacite" do
      visit datacite_work_path(work)
      doc = Nokogiri.XML(page.html)
      nodeset = doc.xpath("/xmlns:resource")
      expect(nodeset).to be_instance_of(Nokogiri::XML::NodeSet)
    end
  end

  context "invalid datacite record" do
    let(:work) { FactoryBot.create :draft_work }
    let(:invalid_xml) { file_fixture("datacite_basic.xml").read.gsub("<creator", "<invalid") }

    before do
      stub_s3
      sign_in user
      allow_any_instance_of(PDCMetadata::Resource).to receive(:to_xml).and_return(invalid_xml)
    end

    it "Validates the record and prints any errors", js: true do
      visit datacite_validate_work_path(work)
      expect(page).to have_content "This element is not expected"
    end
  end
end
