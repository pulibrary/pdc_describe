# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating Thomson Scattering", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:pppl_moderator) }
  let(:title) { "Lower Hybrid Drift Waves During Guide Field Reconnection" }
  let(:description) do
    "Digital data for figures used in Lower Hybrid Drift Waves During Guide Field Reconnection, Geophysical Research Letters, 47, e2020GL087192, 2020."
  end
  let(:ark) { "ark:/88435/dsp0112579w37b" }
  let(:group) { "Princeton Plasma Physics Lab (PPPL)" }
  let(:publisher) { "Princeton University" }
  # DOI of this data set as found at https://www.osti.gov/pages/biblio/1814564
  let(:doi) { "10.11578/1814938" }
  # This is the DOI of the paper that used this data set
  let(:related_identifier) { "10.1029/2020GL087192" }
  let(:related_identifier_type) { "DOI" }
  let(:relation_type) { "IsCitedBy" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.11578"))
    stub_request(:get, "https://handle.stage.datacite.org/10.11578/1814938")
      .to_return(status: 200, body: "", headers: {})
    stub_s3
  end
  context "migrate record from dataspace" do
    it "produces and saves a valid datacite record" do
      sign_in user
      visit "/works/new"
      fill_in "title_main", with: title
      fill_in "description", with: description
      select "Creative Commons Attribution 4.0 International", from: "rights_identifier"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-3881-1995"
      find("tr:last-child input[name='creators[][given_name]']").set "Jongsoo"
      find("tr:last-child input[name='creators[][family_name]']").set "Yoo"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Ji"
      find("tr:last-child input[name='creators[][family_name]']").set "Jeong-Young"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Ambat"
      find("tr:last-child input[name='creators[][family_name]']").set "M.V."
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Wang"
      find("tr:last-child input[name='creators[][family_name]']").set "Shan"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-9600-9963"
      find("tr:last-child input[name='creators[][given_name]']").set "Ji"
      find("tr:last-child input[name='creators[][family_name]']").set "Hantao"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Lo"
      find("tr:last-child input[name='creators[][family_name]']").set "Jenson"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Li"
      find("tr:last-child input[name='creators[][family_name]']").set "Bowen"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-4571-9046"
      find("tr:last-child input[name='creators[][given_name]']").set "Ren"
      find("tr:last-child input[name='creators[][family_name]']").set "Yang"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Jara-Almonte"
      find("tr:last-child input[name='creators[][family_name]']").set "J"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-6289-858X"
      find("tr:last-child input[name='creators[][given_name]']").set "Fox"
      find("tr:last-child input[name='creators[][family_name]']").set "William"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-4996-1649"
      find("tr:last-child input[name='creators[][given_name]']").set "Yamada"
      find("tr:last-child input[name='creators[][family_name]']").set "Masaaki"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-9475-8282"
      find("tr:last-child input[name='creators[][given_name]']").set "Alt"
      find("tr:last-child input[name='creators[][family_name]']").set "Andrew"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Goodman"
      find("tr:last-child input[name='creators[][family_name]']").set "Aaron"

      # Select Additional Metadata Tab
      click_on "Additional Metadata"

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-AC02-09CH11466"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][award_number]']").set "DESC0016278"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][award_number]']").set "DE-FG02-04ER54746"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[4]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[4]//input[@name='funders[][award_number]']").set "DE-FG02-00ER54585"
      click_on "Add Another Funder"
      # https://ror.org/027ka1x80 == ROR for National Aeronautics and Space Administration
      page.find(:xpath, "//table[@id='funding']//tr[5]//input[@name='funders[][ror]']").set "https://ror.org/027ka1x80"
      page.find(:xpath, "//table[@id='funding']//tr[5]//input[@name='funders[][award_number]']").set "NNH14AX63I"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[6]//input[@name='funders[][ror]']").set "https://ror.org/027ka1x80"
      page.find(:xpath, "//table[@id='funding']//tr[6]//input[@name='funders[][award_number]']").set "NNH15AB29I"
      click_on "Add Another Funder"
      # https://ror.org/037gd6g64 == ROR for Division of Atmospheric and Geospace Sciences
      page.find(:xpath, "//table[@id='funding']//tr[7]//input[@name='funders[][ror]']").set "https://ror.org/037gd6g64"
      page.find(:xpath, "//table[@id='funding']//tr[7]//input[@name='funders[][award_number]']").set "AGS-1552142"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[8]//input[@name='funders[][ror]']").set "https://ror.org/037gd6g64"
      page.find(:xpath, "//table[@id='funding']//tr[8]//input[@name='funders[][award_number]']").set "AGS-1619584"
      click_on "Add Another Funder"
      # https://ror.org/021nxhr62 == ROR for National Science Foundation
      page.find(:xpath, "//table[@id='funding']//tr[9]//input[@name='funders[][ror]']").set "https://ror.org/021nxhr62"
      page.find(:xpath, "//table[@id='funding']//tr[9]//input[@name='funders[][award_number]']").set "DE-FG02-00ER54585"

      # Related Objects
      fill_in "related_identifier_1", with: related_identifier
      select related_identifier_type, from: "related_identifier_type_1"
      select relation_type, from: "relation_type_1"

      # Select Curator Controlled Tab
      click_on "Curator Controlled"

      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2020
      select group, from: "group_id"

      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      hybrid_drift_work = Work.last
      expect(hybrid_drift_work.title).to eq title
      expect(hybrid_drift_work.ark).to eq ark

      # Check that RORs were persisted as funder names
      funders = hybrid_drift_work.resource.funders.map(&:funder_name).uniq
      expect(funders).to contain_exactly("United States Department of Energy", "National Aeronautics and Space Administration", "Division of Atmospheric and Geospace Sciences", "National Science Foundation")

      # # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(hybrid_drift_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/hybrid_drift.xml"))
      export_spec_data("hybrid_drift.json", hybrid_drift_work.to_json)
    end
  end
end
