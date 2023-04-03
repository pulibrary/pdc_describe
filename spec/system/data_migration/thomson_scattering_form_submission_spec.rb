# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating Thomson Scattering", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Initial operation and data processing on a system for real-time evaluation of Thomson scattering signals on the Large Helical Device" }
  let(:description) do
    "A scalable system for real-time analysis of electron temperature and density based on signals from the Thomson scattering diagnostic, initially developed for and installed on the NSTX-U experiment, was recently adapted for the Large Helical Device (LHD) and operated for the first time during plasma discharges. During its initial operation run, it routinely recorded and processed signals for four spatial points at the laser repetition rate of 30 Hz, well within the system's rated capability for 60 Hz. We present examples of data collected from this initial run and describe subsequent adaptations to the analysis code to improve the fidelity of the temperature calculations.
    
Please consult the file README.txt for a description of the archive contents."
  end
  let(:ark) { "ark:/88435/dsp014t64gr25v" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "" }
  let(:keywords) { "Thomson scattering, real-time, LHD, plasma diagnostic" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/gg40-tc15")
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
      fill_in "given_name_1", with: "K.C."
      fill_in "family_name_1", with: "Hammond"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "F.M."
      fill_in "family_name_2", with: "Laggner"
      click_on "Add Another Creator"
      fill_in "given_name_3", with: "A."
      fill_in "family_name_3", with: "Diallo"
      click_on "Add Another Creator"
      fill_in "given_name_4", with: "S."
      fill_in "family_name_4", with: "Doskoczynski"
      click_on "Add Another Creator"
      fill_in "given_name_5", with: "C."
      fill_in "family_name_5", with: "Freeman"
      click_on "Add Another Creator"
      fill_in "given_name_6", with: "H."
      fill_in "family_name_6", with: "Funaba"
      click_on "Add Another Creator"
      fill_in "given_name_7", with: "D.A."
      fill_in "family_name_7", with: "Gates"
      click_on "Add Another Creator"
      fill_in "given_name_8", with: "R."
      fill_in "family_name_8", with: "Rozenblat"
      click_on "Add Another Creator"
      fill_in "given_name_9", with: "G."
      fill_in "family_name_9", with: "Tchilinguirian"
      click_on "Add Another Creator"
      fill_in "given_name_10", with: "Z."
      fill_in "family_name_10", with: "Xing"
      click_on "Add Another Creator"
      fill_in "given_name_11", with: "I."
      fill_in "family_name_11", with: "Yamada"
      click_on "Add Another Creator"
      fill_in "given_name_12", with: "R."
      fill_in "family_name_12", with: "Yasuhara"
      click_on "Add Another Creator"
      fill_in "given_name_13", with: "G"
      fill_in "family_name_13", with: "Zimmer"
      click_on "Add Another Creator"
      fill_in "given_name_14", with: "E"
      fill_in "family_name_14", with: "Kolemen"

      click_on "Additional Metadata"
      fill_in "keywords", with: keywords

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-AC02-09CH11466"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][award_number]']").set "DE-SC0015480"
      click_on "Add Another Funder"
      # https://ror.org/01t3wyv61 == ROR for National Institute for Fusion Science
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][ror]']").set "https://ror.org/01t3wyv61"
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][award_number]']").set "ULHH040"
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2021
      select "Research Data", from: "collection_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      thomson_scattering_work = Work.last
      expect(thomson_scattering_work.title).to eq title
      expect(thomson_scattering_work.ark).to eq ark

      # Check that RORs were persisted as funder names
      funders = thomson_scattering_work.resource.funders.map(&:funder_name).uniq
      expect(funders).to contain_exactly("United States Dpertment of Energy", "National Institute for Fusion Science")

      # # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(thomson_scattering_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/thomson_scattering.xml"))
      export_spec_data("thomson_scattering.json", thomson_scattering_work.to_json)
    end
  end
end