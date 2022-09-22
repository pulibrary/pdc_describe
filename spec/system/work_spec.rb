# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system do
  let(:user) { FactoryBot.create(:princeton_submitter) }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  it "Prevents empty title", js: true do
    sign_in user
    visit user_path(user)
    click_on "Submit New"
    fill_in "title_main", with: ""
    click_on "Create New"
    expect(page).to have_content "Must provide a title"
  end

  # this test depends of the fake ORCID server defined in spec/support/orcid_specs.rb
  it "Fills in the creator based on an ORCID ID", js: true do
    sign_in user
    visit new_work_path(params: { wizard: true })
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
    draft_work = FactoryBot.create(:draft_work)
    draft_work_submitter = draft_work.created_by_user

    sign_in draft_work_submitter
    visit edit_work_path(draft_work, wizard: true)
    expect(page.html.include?("By initiating this new submission, we have reserved a draft DOI for your use")).to be true
  end

  it "Handles ARK URLs in the ARK field", js: true, mock_ezid_api: true do
    resource = FactoryBot.build(:resource, creators: [PDCMetadata::Creator.new_person("Harriet", "Tubman", "1234-5678-9012-3456")])
    work = FactoryBot.create(:draft_work, resource: resource)
    user = work.created_by_user
    sign_in user
    visit edit_work_path(work)
    click_on "Identifiers"
    fill_in "ark", with: "http://arks.princeton.edu/ark:/88435/dsp01hx11xj13h"
    click_on "Save Work"
    expect(work.reload.ark).to eq "ark:/88435/dsp01hx11xj13h"
  end

  it "Handles Rights field", js: true do
    resource = FactoryBot.build(:resource, creators: [PDCMetadata::Creator.new_person("Harriet", "Tubman", "1234-5678-9012-3456")])
    work = FactoryBot.create(:draft_work, resource: resource)
    user = work.created_by_user
    sign_in user
    visit edit_work_path(work)
    find("#rights_identifier").find(:xpath, "option[2]").select_option
    click_on "Save Work"
    expect(work.reload.resource.rights.identifier).to eq "CC BY"
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

  context "when editing a work" do
    let(:draft_work) { FactoryBot.create(:draft_work) }
    let(:completed_work) { FactoryBot.create(:completed_work) }
    let(:user) { draft_work.created_by_user }

    it "uses the wizard if the work is in draft" do
      sign_in user
      visit work_path(draft_work)
      expect(page.html.include?("/works/#{draft_work.id}/edit?wizard=true")).to be true
    end

    it "does not use the wizard if the work once the work is not in draft" do
      sign_in user
      visit work_path(completed_work)
      expect(page.html.include?("/works/#{completed_work.id}/edit")).to be true
    end
  end

  context "when editing an existing draft Work with uploaded files" do
    let(:work) { FactoryBot.create(:draft_work) }
    let(:user) { work.created_by_user }

    let(:uploaded_file1) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:uploaded_file2) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:bucket_url) do
      "https://example-bucket.s3.amazonaws.com/"
    end
    let(:drag_javascript) do
      <<-EOF
      const dragSource = document.querySelector('.uploads-row:first-child');
      const dropTarget = document.querySelector('.uploads-row:last-child');

      window.dragMock.dragStart(dragSource).delay(100).dragOver(dropTarget).delay(100).drop(dropTarget);
      EOF
    end

    before do
      stub_request(:put, /#{bucket_url}/).to_return(status: 200)
      work.pre_curation_uploads.attach(uploaded_file1)
      work.pre_curation_uploads.attach(uploaded_file2)

      sign_in user
      visit edit_work_path(work)
    end

    it "shows the uploads before and after errors", js: true do
      # Make the screen larger so the save button is alway on screen.   This avoids random `Element is not clickable` errors
      page.driver.browser.manage.window.resize_to(2000, 2000)
      expect(page).to have_content "us_covid_2019.csv"
      fill_in "title_main", with: ""
      click_on "Save Work"
      expect(page).to have_content "Must provide a title"
      expect(page).to have_content "us_covid_2019.csv"
    end

    it "shows the uploads before and after a valid metadata save", js: true do
      # Make the screen larger so the save button is alway on screen.  This avoids random `Element is not clickable` errors
      page.driver.browser.manage.window.resize_to(2000, 2000)
      expect(page).to have_content "us_covid_2019.csv"
      fill_in "title_main", with: "updated title"
      click_on "Save Work"
      expect(page).to have_content "updated title"
      expect(page).to have_content "us_covid_2019.csv"
    end

    it "allows users to modify the order of the uploads", js: true do
      expect(page).to have_content "Filename"
      expect(page).to have_content "Created At"
      expect(page).to have_content "Replace Upload"
      expect(page).to have_content "Delete Upload"
      expect(page).to have_css('.uploads-row[data-upload-key="0"]', count: 1)
      expect(page).to have_css('.uploads-row[data-upload-key="1"]', count: 1)

      source = page.find('.uploads-row[data-upload-key="0"]')
      target = page.find('.uploads-row[data-upload-key="1"]')

      # This is necessary to interact with the rendered JavaScript <table> rows
      page.scroll_to(target)
      sleep 1

      source.drag_to(target)
      sleep 1

      dragged = page.find('.uploads-row[data-upload-key="0"]')
      expect(dragged[:id]).to eq(source[:id])
    end
  end
end
