# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating Thomson Scattering", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:pppl_moderator) }
  let(:title) { "Initial operation and data processing on a system for real-time evaluation of Thomson scattering signals on the Large Helical Device" }
  let(:description) do
    "A scalable system for real-time analysis of electron temperature and density based on signals from the Thomson scattering diagnostic, initially developed for and installed on the NSTX-U experiment, was recently adapted for the Large Helical Device (LHD) and operated for the first time during plasma discharges. During its initial operation run, it routinely recorded and processed signals for four spatial points at the laser repetition rate of 30 Hz, well within the system's rated capability for 60 Hz. We present examples of data collected from this initial run and describe subsequent adaptations to the analysis code to improve the fidelity of the temperature calculations.

Please consult the file README.txt for a description of the archive contents."
  end
  let(:ark) { "ark:/88435/dsp014t64gr25v" }
  let(:group) { "Princeton Plasma Physics Lab (PPPL)" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.11578/1814942" }
  let(:related_identifier) { "10.1063/5.0041507" }
  let(:related_identifier_type) { "DOI" }
  let(:relation_type) { "IsCitedBy" }

  let(:keywords) { "Thomson scattering, real-time, LHD, plasma diagnostic" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.11578"))
    stub_request(:get, "https://handle.stage.datacite.org/#{doi}")
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
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-1104-4434"
      find("tr:last-child input[name='creators[][given_name]']").set "K.C."
      find("tr:last-child input[name='creators[][family_name]']").set "Hammond"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-1601-2973"
      find("tr:last-child input[name='creators[][given_name]']").set "F.M."
      find("tr:last-child input[name='creators[][family_name]']").set "Laggner"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-0706-060X"
      find("tr:last-child input[name='creators[][given_name]']").set "A."
      find("tr:last-child input[name='creators[][family_name]']").set "Diallo"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "S."
      find("tr:last-child input[name='creators[][family_name]']").set "Doskoczynski"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "C."
      find("tr:last-child input[name='creators[][family_name]']").set "Freeman"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "H."
      find("tr:last-child input[name='creators[][family_name]']").set "Funaba"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-5679-3124"
      find("tr:last-child input[name='creators[][given_name]']").set "D.A."
      find("tr:last-child input[name='creators[][family_name]']").set "Gates"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "R."
      find("tr:last-child input[name='creators[][family_name]']").set "Rozenblat"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-8014-5212"
      find("tr:last-child input[name='creators[][given_name]']").set "G."
      find("tr:last-child input[name='creators[][family_name]']").set "Tchilinguirian"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Z."
      find("tr:last-child input[name='creators[][family_name]']").set "Xing"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "I."
      find("tr:last-child input[name='creators[][family_name]']").set "Yamada"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "R."
      find("tr:last-child input[name='creators[][family_name]']").set "Yasuhara"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-1992-5121"
      find("tr:last-child input[name='creators[][given_name]']").set "G"
      find("tr:last-child input[name='creators[][family_name]']").set "Zimmer"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-4212-3247"
      find("tr:last-child input[name='creators[][given_name]']").set "E."
      find("tr:last-child input[name='creators[][family_name]']").set "Kolemen"

      click_on "Additional Metadata"

      # Related Objects
      find("tr:last-child input[name='related_objects[][related_identifier]']").set related_identifier
      find("tr:last-child select[name='related_objects[][related_identifier_type]']").find(:option, related_identifier_type).select_option
      find("tr:last-child select[name='related_objects[][relation_type]']").find(:option, relation_type).select_option

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
      select group, from: "group_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      thomson_scattering_work = Work.last
      expect(thomson_scattering_work.title).to eq title
      expect(thomson_scattering_work.ark).to eq ark

      # Check that RORs were persisted as funder names
      funders = thomson_scattering_work.resource.funders.map(&:funder_name).uniq
      expect(funders).to contain_exactly("United States Department of Energy", "National Institute for Fusion Science")

      # # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(thomson_scattering_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/thomson_scattering.xml"))
      export_spec_data("thomson_scattering.json", thomson_scattering_work.to_json)
    end
  end
end
