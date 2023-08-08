# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for electromagnetic", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:pppl_moderator) }
  let(:title) { "Electromagnetic total-f algorithm for gyrokinetic particle-in-cell simulations of boundary plasma in XGC" }
  let(:description) do
    "The simplified delta-f mixed-variable/pull-back electromagnetic simulation algorithm implemented in XGC for core plasma simulations by Cole et al. [Phys. Plasmas 28, 034501 (2021)] has been generalized to a total-f electromagnetic algorithm that can include, for the first time, the boundary plasma in diverted magnetic geometry with neutral particle recycling, turbulence and neoclassical physics. The delta-f mixed-variable/pull-back electromagnetic implementation is based on the pioneering work by Kleiber and Mischenko et al. [Kleiber et al., Phys. Plasmas 23, 032501 (2016); Mishchenko et al., Comput. Phys. Commun. 238, 194 (2019)]. An electromagnetic demonstration simulation is performed in a DIII-D-like, H-mode boundary plasma, including a corresponding comparative electrostatic simulation, which confirms that the electromagnetic simulation is necessary for a higher fidelity understanding of the electron particle and heat transport even at the low-beta pedestal foot in the vicinity of the magnetic separatrix..

This data set includes the data visualized in figures 2-7 in Electromagnetic total-f algorithm for gyrokinetic particle-in-cell simulations of boundary plasma in XGC Physics of Plasmas 29, 112308 (2022); https://doi.org/10.1063/5.0097855. The file names indicate to which figure the data belongs. The data files themselves are in self-descriptive HDF5 format."
  end
  let(:ark) { "ark:/88435/dsp01zw12z8539" }
  let(:group) { "Princeton Plasma Physics Lab (PPPL)" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.1063/5.0097855" }
  let(:keywords) { "Tokamak, Magnetic confinement fusion, gyrokinetic, XGC" }
  let(:relation_type) { "IsCitedBy" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.1063"))
    stub_request(:get, "https://handle.stage.datacite.org/10.1063/5.0097855")
      .to_return(status: 200, body: "", headers: {})
    stub_s3
  end
  context "migrate record from dataspace" do
    it "produces and saves a valid datacite record" do
      sign_in user
      visit "/works/new?migrate=true"
      fill_in "title_main", with: title
      fill_in "description", with: description
      select "Creative Commons Attribution 4.0 International", from: "rights_identifiers"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-4624-3150"
      find("tr:last-child input[name='creators[][given_name]']").set "Robert"
      find("tr:last-child input[name='creators[][family_name]']").set "Hager"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-9964-1208"
      find("tr:last-child input[name='creators[][given_name]']").set "Seung-Hoe"
      find("tr:last-child input[name='creators[][family_name]']").set "Ku"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-7946-7425"
      find("tr:last-child input[name='creators[][given_name]']").set "Ami Y."
      find("tr:last-child input[name='creators[][family_name]']").set "Sharma"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-5711-746X"
      find("tr:last-child input[name='creators[][given_name]']").set "Randy Michael"
      find("tr:last-child input[name='creators[][family_name]']").set "Churchill"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-3346-5731"
      find("tr:last-child input[name='creators[][given_name]']").set "C.S."
      find("tr:last-child input[name='creators[][family_name]']").set "Chang"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Aaron"
      find("tr:last-child input[name='creators[][family_name]']").set "Scheinberg"

      click_on "Additional Metadata"
      fill_in "keywords", with: keywords

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-AC02-09CH11466"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][award_number]']").set "DE-AC05-00OR22725"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][award_number]']").set "DE-AC02-06CH11357"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[4]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[4]//input[@name='funders[][award_number]']").set "DE-AC02-05CH11231"
      # Related Objects
      find("tr:last-child input[name='related_objects[][related_identifier]']").set "https://doi.org/10.1063/5.0097855"
      find("tr:last-child select[name='related_objects[][related_identifier_type]']").find(:option, "DOI").select_option
      find("tr:last-child select[name='related_objects[][relation_type]']").find(:option, relation_type).select_option

      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2022
      select group, from: "group_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      electromagnetic_work = Work.last
      expect(electromagnetic_work.title).to eq title
      expect(electromagnetic_work.ark).to eq ark

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(electromagnetic_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/electromagnetic.xml"))
      export_spec_data("electromagnetic.json", electromagnetic_work.to_json)
    end
  end
end
