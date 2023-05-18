# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for observation-axisymmetric", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:pppl_moderator) }
  let(:title) { "Source data for Observation of Axisymmetric Standard Magnetorotational Instability in the Laboratory" }
  let(:description) do
    "Source data for the article Observation of Axisymmetric Standard Magnetorotational Instability in the Laboratory published in Physical Review Letters.

Source data for Figure 2, Figure 4, Figure 5 and Figure 7 of the article Observation of Axisymmetric Standard Magnetorotational Instability in the Laboratory published in Physical Review Letters."
  end
  let(:ark) { "ark:/88435/dsp018623j1954" }
  let(:group) { "Princeton Plasma Physics Laboratory" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.11578/1888278" }
  let(:related_identifier) { "10.1103/PhysRevLett.129.115001" }
  let(:related_identifier_type) { "DOI" }
  let(:relation_type) { "IsCitedBy" }
  let(:keywords) { "magnetorotational instability, taylor-couette flow, liquid metal, mhd instability, accretion disk" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.11578"))
    stub_request(:get, "https://handle.stage.datacite.org/10.11578/1888278")
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
      fill_in "orcid_1", with: "0000-0002-6572-4902"
      fill_in "given_name_1", with: "Yin"
      fill_in "family_name_1", with: "Wang"
      click_on "Add Another Creator"
      fill_in "orcid_2", with: "0000-0001-6820-9132"
      fill_in "given_name_2", with: "Erik"
      fill_in "family_name_2", with: "Gilson"
      click_on "Add Another Creator"
      fill_in "orcid_3", with: "0000-0003-3109-5367"
      fill_in "given_name_3", with: "Fatima"
      fill_in "family_name_3", with: "Ebrahimi"
      click_on "Add Another Creator"
      fill_in "orcid_4", with: "0000-0002-6710-7748"
      fill_in "given_name_4", with: "Jeremy"
      fill_in "family_name_4", with: "Goodman"
      click_on "Add Another Creator"
      fill_in "orcid_5", with: "0000-0001-9600-9963"
      fill_in "given_name_5", with: "Hantao"
      fill_in "family_name_5", with: "Ji"

      click_on "Additional Metadata"

      # Related Objects
      fill_in "related_identifier_1", with: related_identifier
      select related_identifier_type, from: "related_identifier_type_1"
      select relation_type, from: "relation_type_1"

      fill_in "keywords", with: keywords

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-AC02-09CH11466"
      click_on "Add Another Funder"
      # https://ror.org/021nxhr62 == ROR for National Science Foundation
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][ror]']").set "https://ror.org/021nxhr62"
      page.find(:xpath, "//table[@id='funding']//tr[2]//input[@name='funders[][award_number]']").set "AST-2108871"
      click_on "Add Another Funder"
      # https://ror.org/027ka1x80 == ROR for National Aeronautics and Space Administration
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][ror]']").set "https://ror.org/027ka1x80"
      page.find(:xpath, "//table[@id='funding']//tr[3]//input[@name='funders[][award_number]']").set "NNH15AB25I"

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
      observation_axisymmetric_work = Work.last
      expect(observation_axisymmetric_work.title).to eq title
      expect(observation_axisymmetric_work.ark).to eq ark

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(observation_axisymmetric_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/observation_axisymmetric.xml"))
      export_spec_data("observation_axisymmetric.json", observation_axisymmetric_work.to_json)
    end
  end
end
