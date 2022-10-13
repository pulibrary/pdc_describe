# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating cklibrary", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "CKavity Library: Next-Generation Sequencing / A library of novel genes with combinatorially diverse cavities, built on a stably folded structural template" }
  let(:description) do
    "Protein sequence space is vast; nature uses only an infinitesimal fraction of possible sequences to sustain life. Are there solutions to biological problems other than those provided by nature? Can we create artificial proteins that sustain life? To investigate this question, the Hecht lab has created combinatorial collections, or libraries, of novel sequences with no homology to those found in living organisms. These libraries were subjected to screens and selections, leading to the identification of sequences with roles in catalysis, modulating gene regulation, and metal homeostasis. However, the resulting functional proteins formed dynamic rather than well-ordered structures. This impeded structural characterization and made it difficult to ascertain a mechanism of action. To address this, Christina Karas's thesis work focuses on developing a new model of libraries based on the de novo protein S-824, a four-helix bundle with a very stable three-dimensional structure. The first part of this research focused on mutagenesis of S-824 and characterization of the resulting proteins, revealing that this scaffold tolerates amino acid substitutions, including buried polar residues and the removal of hydrophobic side chains to create a putative cavity. Distinct from previous libraries, Karas targeted variability to a specific region of the protein, seeking to create a cavity and potential active site. The second part of this work details the design and creation of a library encoding 1.7 x 10^6 unique proteins, assembled from degenerate oligonucleotides. The third and fourth parts of this work cover the screening effort for a range of activities, both in vitro and in vivo. I found that this collection binds heme readily, leading to abundant peroxidase activity. Hits for lipase and phosphatase activity were also detected. This work details the development of a new strategy for creating de novo sequences geared toward function rather than structure."
  end
  let(:ark) { "ark:/88435/dsp0159999n626m" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University Lewis-Sigler Institute" }
  let(:doi) { "10.34770/gg40-tc15" }
  let(:keywords) { "de novo genes, synthetic, Next-generation sequencing, DNA library" }

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
      find("#rights_identifier").find(:xpath, "option[2]").select_option
      fill_in "given_name_1", with: "Christina"
      fill_in "family_name_1", with: "Karas"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "National Science Foundation"
      click_on "v-pills-additional-tab"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2020
      find("#collection_id").find(:xpath, "option[1]").select_option
      fill_in "keywords", with: keywords
      click_on "v-pills-curator-controlled-tab"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
      expect(page).to have_content "marked as draft"
      cklibrary_work = Work.last
      expect(cklibrary_work.title).to eq title
      puts cklibrary_work.to.xml
    end
  end
end
