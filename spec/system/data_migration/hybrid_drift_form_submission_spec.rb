# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating Thomson Scattering", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:pppl_moderator) }
  let(:title) { "Lower Hybrid Drift Waves During Guide Field Reconnection" }
  let(:description) do
    "Digital data for figures used in Lower Hybrid Drift Waves During Guide Field Reconnection, Geophysical Research Letters, 47, e2020GL087192, 2020."
  end
  let(:ark) { "ark:/88435/dsp0112579w37b" }
  let(:collection) { "Princeton Plasma Physics Laboratory" }
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
      fill_in "orcid_1", with: "0000-0003-3881-1995"
      fill_in "given_name_1", with: "Jongsoo"
      fill_in "family_name_1", with: "Yoo"
      click_on "Add Another Creator"
      fill_in "orcid_2", with: ""
      fill_in "given_name_2", with: "Ji"
      fill_in "family_name_2", with: "Jeong-Young"
      click_on "Add Another Creator"
      fill_in "orcid_3", with: ""
      fill_in "given_name_3", with: "Ambat"
      fill_in "family_name_3", with: "M.V."
      click_on "Add Another Creator"
      fill_in "orcid_4", with: ""
      fill_in "given_name_4", with: "Wang"
      fill_in "family_name_4", with: "Shan"
      click_on "Add Another Creator"
      fill_in "orcid_5", with: "0000-0001-9600-9963"
      fill_in "given_name_5", with: "Ji"
      fill_in "family_name_5", with: "Hantao"
      click_on "Add Another Creator"
      fill_in "orcid_6", with: ""
      fill_in "given_name_6", with: "Lo"
      fill_in "family_name_6", with: "Jenson"
      click_on "Add Another Creator"
      fill_in "orcid_7", with: ""
      fill_in "given_name_7", with: "Li"
      fill_in "family_name_7", with: "Bowen"
      click_on "Add Another Creator"
      fill_in "orcid_8", with: "0000-0003-4571-9046"
      fill_in "given_name_8", with: "Ren"
      fill_in "family_name_8", with: "Yang"
      click_on "Add Another Creator"
      fill_in "orcid_9", with: ""
      fill_in "given_name_9", with: "Jara-Almonte"
      fill_in "family_name_9", with: "J"
      click_on "Add Another Creator"
      fill_in "orcid_10", with: "0000-0001-6289-858X"
      fill_in "given_name_10", with: "Fox"
      fill_in "family_name_10", with: "William"
      click_on "Add Another Creator"
      fill_in "orcid_11", with: "0000-0003-4996-1649"
      fill_in "given_name_11", with: "Yamada"
      fill_in "family_name_11", with: "Masaaki"
      click_on "Add Another Creator"
      fill_in "orcid_12", with: "0000-0001-9475-8282"
      fill_in "given_name_12", with: "Alt"
      fill_in "family_name_12", with: "Andrew"
      click_on "Add Another Creator"
      fill_in "orcid_13", with: ""
      fill_in "given_name_13", with: "Goodman"
      fill_in "family_name_13", with: "Aaron"

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
      select collection, from: "group_id"

      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
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
