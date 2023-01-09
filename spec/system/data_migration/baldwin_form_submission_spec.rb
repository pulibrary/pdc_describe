# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating baldwin", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Supporting data for Baldwin et al 2019 \"Temporally Compound Heat Waves and Global Warming: An Emerging Hazard\"" }
  let(:description) do
    "This data is compiled to support a publication in the journal Earth's Future: Baldwin et al 2019 \"Temporally Compound Heat Waves and Global Warming: An Emerging Hazard\". The GCM GFDL CM2.5-FLOR was used to produce the raw climate model data. The model code for FLOR is freely available and can be downloaded at https://www.gfdl.noaa.gov/cm2-5-and-flor/. Code used to calculate the derived heat wave statistics data and produce figures in the paper is available at https://github.com/janewbaldwin/Compound-Heat-Waves The heat wave statistics derived output for only one definition is provided (daily minimum temperature, 90th percentile threshold, temporal structure 3114) which is the definition used the most in the paper figures. Statistics for the other definitions can be created by running the HWSTATS code provided in the corresponding github folder, which includes python scripts which do the analysis and PBS job scheduling and submission scripts which show how to run the python scripts. For more information on this, please see the github readme.

A full description of the structure of the dataset and how to reproduce the figures in the manuscript are given in the dataset README file. This dataset is too large to download directly from this item page. You can access and download the data via Globus at this link: https://app.globus.org/file-manager?origin_id=dc43f461-0ca7-4203-848c-33a9fc00a464&origin_path=%2Fxajd-5n64%2F (See https://docs.globus.org/how-to/get-started/ for instructions on how to use Globus; sign-in is required)."
  end
  let(:ark) { "ark:/88435/dsp01bz60d033c" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/xajd-5n64" }

  before do
    page.driver.browser.manage.window.resize_to(2000, 2000)
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
      find("#rights_identifier").find(:xpath, "option[2]").select_option
      fill_in "given_name_1", with: "Jane W"
      fill_in "family_name_1", with: "Baldwin"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "Jay Benjamin"
      fill_in "family_name_2", with: "Dessy"
      click_on "Add Another Creator"
      fill_in "given_name_3", with: "Gabriel A"
      fill_in "family_name_3", with: "Vecchi"
      click_on "Add Another Creator"
      fill_in "given_name_4", with: "Michael"
      fill_in "family_name_4", with: "Oppenheimer"
      click_on "Add Another Creator"
      fill_in "given_name_5", with: "Liwei"
      fill_in "family_name_5", with: "Jia"
      click_on "Add Another Creator"
      fill_in "given_name_6", with: "Richard G"
      fill_in "family_name_6", with: "Gudgel"
      click_on "Add Another Creator"
      fill_in "given_name_7", with: "Karen"
      fill_in "family_name_7", with: "Paffendorf"
      click_on "v-pills-additional-tab"
      click_on "v-pills-curator-controlled-tab"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2019
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      find("#collection_id").find(:xpath, "option[1]").select_option
      click_on "Create"
      expect(page).to have_content "marked as Draft"
      baldwin_work = Work.last
      expect(baldwin_work.title).to eq title

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(baldwin_work)
      expect(datacite.valid?).to eq true

      export_spec_data("baldwin.json", baldwin_work.to_json)
    end
  end
end
