# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating bitklavier", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It" }
  let(:description) do
    "In 2017, seven members of the Archive-It Mid-Atlantic Users Group (AITMA) conducted a study of 14 subjects representative of their stakeholder populations to assess the usability of Archive-It, a web archiving subscription service of the Internet Archive. While Archive-It is the most widely-used tool for web archiving, little is known about how users interact with the service.This study intended to teach us what users expect from web archives, which exist as another form of archival material. End-user subjects executed four search tasks using the public Archive-It interface and the Wayback Machine to access archived information on websites from the facilitators’ own harvested collections and provide feedback about their experiences. The tasks were designed to have straightforward pass or fail outcomes,
    and the facilitators took notes on the subjects’ behavior and commentary during the sessions.Overall, participants reported mildly positive impressions of Archive-It public user interface based on their session. The study identified several key areas of improvement for the Archive-It service pertaining to metadata options, terminology display, indexing of dates, and the site’s search box.

Download the README.txt for a detailed description of this dataset's content."
  end
  let(:ark) { "ark:/88435/dsp01d791sj97j" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) {}
  let(:file1) { Pathname.new(fixture_path).join("dataspace_migration", "sowingseeds", "readmearchiveitusability.rtf").to_s }
  let(:file2) { Pathname.new(fixture_path).join("dataspace_migration", "sowingseeds", "Archive-It-UsabilityTestDataAnalysis-2017.xlsx").to_s }
  let(:bucket_url) do
    "https://example-bucket.s3.amazonaws.com/"
  end

  before do
    page.driver.browser.manage.window.resize_to(2000, 2000)
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/r75s-9j74")
      .to_return(status: 200, body: "", headers: {})
    stub_request(:put, /#{bucket_url}/).to_return(status: 200)
  end
  context "migrate record from dataspace" do
    it "produces and saves a valid datacite record" do
      sign_in user
      # we need to use the wizard because this work does not have a doi and it needs one to be registered
      visit "/works/new"
      fill_in "title_main", with: title
      fill_in "given_name_1", with: "Samantha"
      fill_in "family_name_1", with: "Abrams"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "Alexis"
      fill_in "family_name_2", with: "Antracoli"
      click_on "Add Another Creator"
      fill_in "given_name_3", with: "Rachel"
      fill_in "family_name_3", with: "Appel"
      click_on "Add Another Creator"
      fill_in "given_name_4", with: "Celia"
      fill_in "family_name_4", with: "Caust-Ellenbogen"
      click_on "Add Another Creator"
      fill_in "given_name_5", with: "Sarah"
      fill_in "family_name_5", with: "Dennison"
      click_on "Add Another Creator"
      fill_in "given_name_6", with: "Sumitra"
      fill_in "family_name_6", with: "Duncan"
      click_on "Add Another Creator"
      fill_in "given_name_7", with: "Stefanie"
      fill_in "family_name_7", with: "Ramsay"
      fill_in "description", with: description
      select "Creative Commons Attribution 4.0 International", from: "rights_identifier"
      page.attach_file("work[pre_curation_uploads][]", [file1, file2], make_visible: true)
      click_on "Additional Metadata"
      click_on "Curator Controlled"
      fill_in "ark", with: ark
      click_on "Create"
      click_on "Complete"
      click_on "Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It"

      # the work has been submitted and is awaiting_approval
      expect(page).to have_content "awaiting_approval"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      sowingseeds_work = Work.last
      expect(sowingseeds_work.title).to eq title
      expect(sowingseeds_work.ark).to eq ark

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(sowingseeds_work)
      expect(datacite.valid?).to eq true
      export_spec_data("sowingseeds.json", sowingseeds_work.to_json)
    end
  end
end
