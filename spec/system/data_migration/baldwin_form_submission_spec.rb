# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating baldwin", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Supporting data for Baldwin et al 2019 \"Temporally Compound Heat Waves and Global Warming: An Emerging Hazard\"" }
  let(:description) do
    "This data is compiled to support a publication in the journal Earth's Future: Baldwin et al 2019 \"Temporally Compound Heat Waves and Global Warming: An Emerging Hazard\". The GCM GFDL CM2.5-FLOR was used to produce the raw climate model data. The model code for FLOR is freely available and can be downloaded at https://www.gfdl.noaa.gov/cm2-5-and-flor/. Code used to calculate the derived heat wave statistics data and produce figures in the paper is available at https://github.com/janewbaldwin/Compound-Heat-Waves The heat wave statistics derived output for only one definition is provided (daily minimum temperature, 90th percentile threshold, temporal structure 3114) which is the definition used the most in the paper figures. Statistics for the other definitions can be created by running the HWSTATS code provided in the corresponding github folder, which includes python scripts which do the analysis and PBS job scheduling and submission scripts which show how to run the python scripts. For more information on this, please see the github readme."
  end
  let(:ark) { "ark:/88435/dsp01bz60d033c" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/xajd-5n64" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/xajd-5n64")
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
      find("tr:last-child input[name='creators[][given_name]']").set "Jane W"
      find("tr:last-child input[name='creators[][family_name]']").set "Baldwin"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Jay Benjamin"
      find("tr:last-child input[name='creators[][family_name]']").set "Dessy"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Gabriel A"
      find("tr:last-child input[name='creators[][family_name]']").set "Vecchi"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Michael"
      find("tr:last-child input[name='creators[][family_name]']").set "Oppenheimer"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Liwei"
      find("tr:last-child input[name='creators[][family_name]']").set "Jia"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Richard G"
      find("tr:last-child input[name='creators[][family_name]']").set "Gudgel"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Karen"
      find("tr:last-child input[name='creators[][family_name]']").set "Paffendorf"
      click_on "Additional Metadata"
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2019
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      select "Research Data", from: "group_id"
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      baldwin_work = Work.last
      expect(baldwin_work.title).to eq title
      expect(baldwin_work.ark).to eq ark

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(baldwin_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/baldwin.xml"))
      export_spec_data("baldwin.json", baldwin_work.to_json)
    end
  end
end
