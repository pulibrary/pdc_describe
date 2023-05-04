# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating attention", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:pppl_moderator) }
  let(:title) { "Data for The value of fusion energy to a decarbonized United States electric grid" }
  let(:description) do
    "Fusion could be a part of future decarbonized electricity systems, but it will need to compete with other technologies. In particular, pulsed tokamaks plants have a unique operational mode, and evaluating which characteristics make them economically competitive can help select between design pathways. Using a capacity expansion and operations model, we determined cost thresholds for pulsed tokamaks to reach a range of penetration levels in a future decarbonized US Eastern Interconnection. The required capital cost to reach a fusion capacity of 100 GW varied from $3000 to $7200/kW, and the equilibrium penetration increases rapidly with decreasing cost. The value per unit power capacity depends on the variable operational cost and on cost of its competition, particularly fission, much more than on the pulse cycle parameters. These findings can therefore provide initial cost targets for fusion more generally in the United States. This dataset is too large to download directly from this item page. You can access and download the data via Globus at this link: https://app.globus.org/file-manager?destination_id=dc43f461-0ca7-4203-848c-33a9fc00a464&destination_path=%2Ff8em-3c49%2F (See https://docs.globus.org/how-to/get-started/ for instructions on how to use Globus; sign-in is required)."
  end
  let(:ark) { "ark:/88435/dsp012j62s808w" }
  let(:collection) { "Princeton Plasma Physics Laboratory" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.5281/zenodo.7507006" }
  let(:keywords) { "fusion, economics, cost, value, tokamak, power plant" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.5281"))
    stub_request(:get, "https://handle.stage.datacite.org/10.5281/zenodo.7507006")
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
      fill_in "orcid_1", with: "0000-0001-9636-8181"
      fill_in "given_name_1", with: "Jacob A."
      fill_in "family_name_1", with: "Schwartz"
      click_on "Add Another Creator"
      fill_in "orcid_2", with: ""
      fill_in "given_name_2", with: "Wilson"
      fill_in "family_name_2", with: "Ricks"
      click_on "Add Another Creator"
      fill_in "orcid_3", with: "0000-0003-4212-3247"
      fill_in "given_name_3", with: "Egemen"
      fill_in "family_name_3", with: "Kolemen"
      click_on "Add Another Creator"
      fill_in "orcid_4", with: "0000-0002-9670-7793"
      fill_in "given_name_4", with: "Jesse D."
      fill_in "family_name_4", with: "Jenkins"

      click_on "Additional Metadata"

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-AC02-09CH11466"

      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2022
      select collection, from: "collection_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      fusion_energy_work = Work.last
      expect(fusion_energy_work.title).to eq title
      expect(fusion_energy_work.ark).to eq ark

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(fusion_energy_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/fusion_energy.xml"))
      export_spec_data("fusion_energy.json", fusion_energy_work.to_json)
    end
  end
end
