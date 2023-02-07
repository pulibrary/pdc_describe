# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating femtosecond", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Femtosecond X-ray Diffraction of Laser-shocked Forsterite (Mg2SiO4) to 122 GPa" }
  let(:description) do
    "The behavior of forsterite, Mg2SiO4, under dynamic compression is of fundamental importance for understanding its phase transformations and high-pressure behavior. Here, we have carried out an in situ X-ray diffraction study of laser-shocked poly- and single-crystal forsterite (a-, b-, and c- orientations) from 19 to 122 GPa using the Matter in Extreme Conditions end-station of the Linac Coherent Light Source. Under laser-based shock loading, forsterite does not transform to the high-pressure equilibrium assemblage of MgSiO3 bridgmanite and MgO periclase, as was suggested previously. Instead, we observe forsterite and forsterite III, a metastable polymorph of Mg2SiO4, coexisting in a mixed-phase region from 33 to 75 GPa for both polycrystalline and single-crystal samples. Densities inferred from X-ray diffraction data are consistent with earlier gas-gun shock data. At higher stress, the behavior observed is sample-dependent. Polycrystalline samples undergo amorphization above 79 GPa. For [010]- and [001]-oriented crystals, a mixture of crystalline and amorphous material is observed to 108 GPa, whereas the [100]-oriented crystal adopts an unknown crystal structure at 122 GPa. The Q values of the first two sharp diffraction peaks of amorphous Mg2SiO4 show a similar trend with compression as those observed for MgSiO3 glass in both recent static and laser-compression experiments. Upon release to ambient pressure, all samples retain or revert to forsterite with evidence for amorphous material also present in some cases. This study demonstrates the utility of femtosecond free-electron laser X-ray sources for probing the time evolution of high-pressure silicates through the nanosecond-scale events of shock compression and release."
  end
  let(:ark) { "ark:/88435/dsp01rj4307478" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/gg40-tc15" }
  let(:keywords) { "shock compression, forsterite, phase transition, amorphization" }

  before do
    page.driver.browser.manage.window.resize_to(2000, 2000)
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
      fill_in "given_name_1", with: "Donghoon"
      fill_in "family_name_1", with: "Kim"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "Sally J"
      fill_in "family_name_2", with: "Tracy"
      click_on "Add Another Creator"
      fill_in "given_name_3", with: "Raymond F"
      fill_in "family_name_3", with: "Smith"
      click_on "Add Another Creator"
      fill_in "given_name_4", with: "Arianna E"
      fill_in "family_name_4", with: "Gleason"
      click_on "Add Another Creator"
      fill_in "given_name_5", with: "Cindy A"
      fill_in "family_name_5", with: "Bolme"
      click_on "Add Another Creator"
      fill_in "given_name_6", with: "Vitali B"
      fill_in "family_name_6", with: "Prakapenka"
      click_on "Add Another Creator"
      fill_in "given_name_7", with: "Karen"
      fill_in "family_name_7", with: "Appel"
      click_on "Add Another Creator"
      fill_in "given_name_8", with: "Sergio"
      fill_in "family_name_8", with: "Speziable"
      click_on "Add Another Creator"
      fill_in "given_name_9", with: "June K"
      fill_in "family_name_9", with: "Wicks"
      click_on "Add Another Creator"
      fill_in "given_name_10", with: "Eleanor J"
      fill_in "family_name_10", with: "Berryman"
      click_on "Add Another Creator"
      fill_in "given_name_11", with: "Sirus K"
      fill_in "family_name_11", with: "Han"
      click_on "Add Another Creator"
      fill_in "given_name_12", with: "Markus O"
      fill_in "family_name_12", with: "Schoelmerich"
      click_on "Add Another Creator"
      fill_in "given_name_13", with: "Hae Ja"
      fill_in "family_name_13", with: "Lee"
      click_on "Add Another Creator"
      fill_in "given_name_14", with: "Bob"
      fill_in "family_name_14", with: "Nagler"
      click_on "Add Another Creator"
      fill_in "given_name_15", with: "Eric F"
      fill_in "family_name_15", with: "Cunningham"
      click_on "Add Another Creator"
      fill_in "given_name_16", with: "Minta C"
      fill_in "family_name_16", with: "Akin"
      click_on "Add Another Creator"
      fill_in "given_name_17", with: "Paul D"
      fill_in "family_name_17", with: "Asimow"
      click_on "Add Another Creator"
      fill_in "given_name_18", with: "Jon H"
      fill_in "family_name_18", with: "Eggert"
      click_on "Add Another Creator"
      fill_in "given_name_19", with: "Thomas S"
      fill_in "family_name_19", with: "Duffy"

      click_on "Additional Metadata"
      fill_in "keywords", with: keywords

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-SC0018925"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][award_number]']").set "DE-AC02-76SF00515"
      click_on "Add Another Funder"
      # https://ror.org/021nxhr62 == ROR for National Science Foundation
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][ror]']").set "https://ror.org/021nxhr62"
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][award_number]']").set "EAR-1644614"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[4]//input[@name='funders[][ror]']").set "https://ror.org/021nxhr62"
      page.find(:xpath, "//table[@id='funding']//tr[4]//input[@name='funders[][award_number]']").set "EAR-1446969"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[5]//input[@name='funders[][ror]']").set "https://ror.org/021nxhr62"
      page.find(:xpath, "//table[@id='funding']//tr[5]//input[@name='funders[][award_number]']").set "EAR-1725349"
      click_on "Add Another Funder"
      # https://ror.org/018mejw64 == ROR for Deutsche Forschungsgemeinschaft a.k.a. DFG, German Research Foundation
      page.find(:xpath, "//table[@id='funding']//tr[6]//input[@name='funders[][ror]']").set "https://ror.org/018mejw64"
      page.find(:xpath, "//table[@id='funding']//tr[6]//input[@name='funders[][award_number]']").set "AP 262/2-1"
      click_on "Add Another Funder"
      page.find(:xpath, "//table[@id='funding']//tr[7]//input[@name='funders[][ror]']").set "https://ror.org/018mejw64"
      page.find(:xpath, "//table[@id='funding']//tr[7]//input[@name='funders[][award_number]']").set "FOR2440"
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2020
      select "Research Data", from: "collection_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      femtosecond_work = Work.last
      expect(femtosecond_work.title).to eq title
      expect(femtosecond_work.ark).to eq ark

      # Check that RORs were persisted as funder names
      funders = femtosecond_work.resource.funders.map(&:funder_name).uniq
      expect(funders).to contain_exactly("United States Department of Energy", "National Science Foundation", "Deutsche Forschungsgemeinschaft")

      # # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(femtosecond_work)
      expect(datacite.valid?).to eq true
      # expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/femtosecond.xml"))
      export_spec_data("femtosecond.json", femtosecond_work.to_json)
    end
  end
end
