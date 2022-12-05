# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating cytoskeletal", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Distinct cytoskeletal proteins define zones of enhanced cell wall synthesis in Helicobacter pylori" }
  let(:description) do
    "Helical cell shape is necessary for efficient stomach colonization by Helicobacter pylori, but the molecular mechanisms for generating helical shape remain unclear. We show that the helical centerline pitch and radius of wild-type H. pylori cells dictate surface curvatures of considerably higher positive and negative Gaussian curvatures than those present in straight- or curved-rod bacteria. Quantitative 3D microscopy analysis of short pulses with either N-acetylmuramic acid or D-alanine metabolic probes showed that cell wall growth is enhanced at both sidewall curvature extremes. Immunofluorescence revealed MreB is most abundant at negative Gaussian curvature, while the bactofilin CcmA is most abundant at positive Gaussian curvature. Strains expressing CcmA variants with altered polymerization properties lose helical shape and associated positive Gaussian curvatures. We thus propose a model where CcmA and MreB promote PG synthesis at positive and negative Gaussian curvatures, respectively, and that this patterning is one mechanism necessary for maintaining helical shape. This dataset includes structured illumination fluorescence microscopy images (SIM) and their associated cell shape reconstructions, phase contrast micrographs, and transmission electron micrographs. See the README.txt for detailed description of the strains and conditions represented in each data file."
  end
  let(:ark) { "ark:/88435/dsp01h415pd457" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/r2dz-ys12" }
  let(:related_identifier) { "https://www.biorxiv.org/content/10.1101/545517v1" }
  let(:related_identifier_type) { "ARXIV" }
  let(:relation_type) { "IS_CITED_BY" }

  before do
    page.driver.browser.manage.window.resize_to(2000, 2000)
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/r2dz-ys12")
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
      fill_in "given_name_1", with: "Jenny A"
      fill_in "family_name_1", with: "Taylor"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "Benjamin P"
      fill_in "family_name_2", with: "Bratton"
      click_on "Add Another Creator"
      fill_in "given_name_3", with: "Sophie R"
      fill_in "family_name_3", with: "Sichel"
      click_on "Add Another Creator"
      fill_in "given_name_4", with: "Kris M"
      fill_in "family_name_4", with: "Blair"
      click_on "Add Another Creator"
      fill_in "given_name_5", with: "Holly M"
      fill_in "family_name_5", with: "Jacobs"
      click_on "Add Another Creator"
      fill_in "given_name_6", with: "Kristen E"
      fill_in "family_name_6", with: "DeMeester"
      click_on "Add Another Creator"
      fill_in "given_name_7", with: "Erkin"
      fill_in "family_name_7", with: "Kuru"
      click_on "Add Another Creator"
      fill_in "given_name_8", with: "Joe"
      fill_in "family_name_8", with: "Gray"
      click_on "Add Another Creator"
      fill_in "given_name_9", with: "Jacob"
      fill_in "family_name_9", with: "Biboy"
      click_on "Add Another Creator"
      fill_in "given_name_10", with: "Michael S"
      fill_in "family_name_10", with: "VanNieuwenhze"
      click_on "Add Another Creator"
      fill_in "given_name_11", with: "Waldemar"
      fill_in "family_name_11", with: "Vollmer"
      click_on "Add Another Creator"
      fill_in "given_name_12", with: "Catherine L"
      fill_in "family_name_12", with: "Grimes"
      click_on "Add Another Creator"
      fill_in "given_name_13", with: "Joshua W"
      fill_in "family_name_13", with: "Shaevitz"
      click_on "Add Another Creator"
      fill_in "given_name_14", with: "Nina R"
      fill_in "family_name_14", with: "Salama"
      click_on "v-pills-curator-controlled-tab"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2019
      find("#collection_id").find(:xpath, "option[1]").select_option

      # Select Additional Metadata Tab
      click_on "v-pills-additional-tab"

      # Related Objects
      fill_in "related_identifier_1", with: related_identifier
      find("#related_identifier_type_1").find(:xpath, "option[@value='#{related_identifier_type}']").select_option
      find("#relation_type_1").find(:xpath, "option[@value='#{relation_type}']").select_option
      click_on "Add Another Related Object"
      fill_in "related_identifier_2", with: "https://doi.org/10.7554/eLife.52482"
      find("#related_identifier_type_2").find(:xpath, "option[@value='DOI']").select_option
      find("#relation_type_2").find(:xpath, "option[@value='#{relation_type}']").select_option

      # Select Curator Controlled Tab
      click_on "v-pills-curator-controlled-tab"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
      expect(page).to have_content "marked as draft"
      cytoskeletal_work = Work.last
      expect(cytoskeletal_work.title).to eq title
      expect(cytoskeletal_work.resource.related_objects.first.related_identifier).to eq related_identifier
      expect(cytoskeletal_work.resource.related_objects.first.related_identifier_type).to eq related_identifier_type
      expect(cytoskeletal_work.resource.related_objects.first.relation_type).to eq relation_type
      # ARK is not a related object in the resource, but it IS a "related identifer" in the DataCite serialization
      # This object has 2 related objects, but 3 related identifiers
      expect(cytoskeletal_work.resource.related_objects.count).to eq 2
      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(cytoskeletal_work)
      expect(datacite.valid?).to eq true
    end
  end
end
