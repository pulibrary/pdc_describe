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
  let(:group) { "Princeton Plasma Physics Laboratory" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.1063/5.0097855" }
  let(:keywords) { "Tokamak, Magnetic confinement fusion, gyrokinetic, XGC" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.1063"))
    stub_request(:get, "https://handle.stage.datacite.org/10.1063/5.0097855")
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
      fill_in "orcid_1", with: "0000-0002-4624-3150"
      fill_in "given_name_1", with: "Robert"
      fill_in "family_name_1", with: "Hager"
      click_on "Add Another Creator"
      fill_in "orcid_2", with: "0000-0002-9964-1208"
      fill_in "given_name_2", with: "Seung-Hoe"
      fill_in "family_name_2", with: "Ku"
      click_on "Add Another Creator"
      fill_in "orcid_3", with: "0000-0002-7946-7425"
      fill_in "given_name_3", with: "Ami Y."
      fill_in "family_name_3", with: "Sharma"
      click_on "Add Another Creator"
      fill_in "orcid_4", with: "0000-0001-5711-746X"
      fill_in "given_name_4", with: "Randy Michael"
      fill_in "family_name_4", with: "Churchill"
      click_on "Add Another Creator"
      fill_in "orcid_5", with: "0000-0002-3346-5731"
      fill_in "given_name_5", with: "C.S."
      fill_in "family_name_5", with: "Chang"
      click_on "Add Another Creator"
      fill_in "orcid_6", with: ""
      fill_in "given_name_6", with: "Aaron"
      fill_in "family_name_6", with: "Scheinberg"

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
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2022
      select group, from: "group_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
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
