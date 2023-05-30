# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating cytoskeletal", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Distinct cytoskeletal proteins define zones of enhanced cell wall synthesis in Helicobacter pylori" }
  let(:description) do
    "Helical cell shape is necessary for efficient stomach colonization by Helicobacter pylori, but the molecular mechanisms for generating helical shape remain unclear. We show that the helical centerline pitch and radius of wild-type H. pylori cells dictate surface curvatures of considerably higher positive and negative Gaussian curvatures than those present in straight- or curved-rod bacteria. Quantitative 3D microscopy analysis of short pulses with either N-acetylmuramic acid or D-alanine metabolic probes showed that cell wall growth is enhanced at both sidewall curvature extremes. Immunofluorescence revealed MreB is most abundant at negative Gaussian curvature, while the bactofilin CcmA is most abundant at positive Gaussian curvature. Strains expressing CcmA variants with altered polymerization properties lose helical shape and associated positive Gaussian curvatures. We thus propose a model where CcmA and MreB promote PG synthesis at positive and negative Gaussian curvatures, respectively, and that this patterning is one mechanism necessary for maintaining helical shape. This dataset includes structured illumination fluorescence microscopy images (SIM) and their associated cell shape reconstructions, phase contrast micrographs, and transmission electron micrographs. See the README.txt for detailed description of the strains and conditions represented in each data file."
  end
  let(:ark) { "ark:/88435/dsp01h415pd457" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/r2dz-ys12" }
  let(:related_identifier) { "https://www.biorxiv.org/content/10.1101/545517v1" }
  let(:related_identifier_type) { "arXiv" }
  let(:relation_type) { "IsCitedBy" }

  before do
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
      select "Creative Commons Attribution 4.0 International", from: "rights_identifier"
      find("tr:last-child input[name='creators[][given_name]']").set "Jenny A"
      find("tr:last-child input[name='creators[][family_name]']").set "Taylor"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Benjamin P"
      find("tr:last-child input[name='creators[][family_name]']").set "Bratton"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Sophie R"
      find("tr:last-child input[name='creators[][family_name]']").set "Sichel"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Kris M"
      find("tr:last-child input[name='creators[][family_name]']").set "Blair"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Holly M"
      find("tr:last-child input[name='creators[][family_name]']").set "Jacobs"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Kristen E"
      find("tr:last-child input[name='creators[][family_name]']").set "DeMeester"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Erkin"
      find("tr:last-child input[name='creators[][family_name]']").set "Kuru"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Joe"
      find("tr:last-child input[name='creators[][family_name]']").set "Gray"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Jacob"
      find("tr:last-child input[name='creators[][family_name]']").set "Biboy"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Michael S"
      find("tr:last-child input[name='creators[][family_name]']").set "VanNieuwenhze"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Waldemar"
      find("tr:last-child input[name='creators[][family_name]']").set "Vollmer"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Catherine L"
      find("tr:last-child input[name='creators[][family_name]']").set "Grimes"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Joshua W"
      find("tr:last-child input[name='creators[][family_name]']").set "Shaevitz"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Nina R"
      find("tr:last-child input[name='creators[][family_name]']").set "Salama"
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2019
      select "Research Data", from: "group_id"

      # Select Additional Metadata Tab
      click_on "Additional Metadata"

      # Related Objects
      fill_in "related_identifier_1", with: related_identifier
      select related_identifier_type, from: "related_identifier_type_1"
      select relation_type, from: "relation_type_1"
      click_on "Add Another Related Object"
      fill_in "related_identifier_2", with: "https://doi.org/10.7554/eLife.52482"
      select "DOI", from: "related_identifier_type_2"
      select relation_type, from: "relation_type_2"

      # Select Curator Controlled Tab
      click_on "Curator Controlled"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      cytoskeletal_work = Work.last
      expect(cytoskeletal_work.title).to eq title
      expect(cytoskeletal_work.ark).to eq ark
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
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/cytoskeletal.xml"))
      export_spec_data("cytoskeletal.json", cytoskeletal_work.to_json)
    end
  end
end
