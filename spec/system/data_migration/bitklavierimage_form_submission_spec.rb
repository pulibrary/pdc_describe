# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating bitklavierimage", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "bitKlavier Grand Sample Library—Piano Bar Mic Image" }
  let(:description) do
    "The bitKlavier Grand consists of sample collections of a new Steinway D grand piano from nine different stereo mic images, with: 16 velocity layers, at every minor 3rd (starting at A0); Hammer release samples; Release resonance samples; Pedal samples.
Release packages at 96k/24bit, 88.2k/24bit, 48k/24bit, 44.1k/16bit are available for various applications.
Piano Bar: Earthworks—omni-directionals. This microphone system suspends omnidirectional microphones within the piano. The bar is placed across the harp near the hammers and provides a low string / high string player’s perspective. It also produces a close sound without room or lid interactions. It can be panned across an artificial stereophonic perspective effectively in post-production. File Naming Convention: C4 = middle C. Main note names: [note name][octave]v[velocity].wav -- e.g., “D#5v13.wav”. Release resonance notes: harm[note name][octave]v[velocity].wav -- e.g., “harmC2v2.wav”. Hammer samples: rel[1-88].wav (one per key) -- e.g., “rel23.wav”. Pedal samples: pedal[D/U][velocity].wav -- e.g., “pedalU2.wav” => pedal release (U = up), velocity = 2 (quicker release than velocity = 1)."
  end
  let(:ark) { "ark:/88435/dsp015999n653h" }
  let(:collection_tags) { ["bitklavier"] }
  let(:group) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/r75s-9j74" }
  let(:keywords) { "bitKlavier, sample library, piano" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/r75s-9j74")
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
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Matthew"
      find("tr:last-child input[name='creators[][family_name]']").set "Wang"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Andres"
      find("tr:last-child input[name='creators[][family_name]']").set "Villalta"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Jeffrey"
      find("tr:last-child input[name='creators[][family_name]']").set "Gordon"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Katie"
      find("tr:last-child input[name='creators[][family_name]']").set "Chou"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Christien"
      find("tr:last-child input[name='creators[][family_name]']").set "Ayers"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Daniel"
      find("tr:last-child input[name='creators[][family_name]']").set "Trueman"
      click_on "Additional Metadata"
      fill_in "keywords", with: keywords
      # Select Additional Metadata Tab
      click_on "Additional Metadata"
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2021
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      select group, from: "group_id"
      fill_in "collection_tags", with: collection_tags.join(", ")
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      bitklavierimage_work = Work.last
      expect(bitklavierimage_work.title).to eq title
      expect(bitklavierimage_work.resource.collection_tags).to eq collection_tags
      expect(bitklavierimage_work.group).to eq Group.research_data
      expect(bitklavierimage_work.ark).to eq ark
      export_spec_data("bitklavier_image.json", bitklavierimage_work.to_json)

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(bitklavierimage_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/bitklavierimage.xml"))
    end
  end
end
