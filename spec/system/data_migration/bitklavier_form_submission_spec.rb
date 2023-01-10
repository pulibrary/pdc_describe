# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating bitklavier", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "bitKlavier Grand Sample Library—Binaural Mic Image" }
  let(:description) do
    "The bitKlavier Grand consists of sample collections of a new Steinway D grand piano from nine different stereo mic images, with: 16 velocity layers, at every minor 3rd (starting at A0); Hammer release samples; Release resonance samples; Pedal samples. Release packages at 96k/24bit, 88.2k/24bit, 48k/24bit, 44.1k/16bit are available for various applications.
  Piano Bar: Earthworks—omni-directionals. This microphone system suspends omnidirectional microphones within the piano. The bar is placed across the harp near the hammers and provides a low string / high string player’s perspective. It also produces a close sound without room or lid interactions. It can be panned across an artificial stereophonic perspective effectively in post-production. File Naming Convention: C4 = middle C. Main note names: [note name][octave]v[velocity].wav -- e.g., “D#5v13.wav”. Release resonance notes: harm[note name][octave]v[velocity].wav -- e.g., “harmC2v2.wav”. Hammer samples: rel[1-88].wav (one per key) -- e.g., “rel23.wav”. Pedal samples: pedal[D/U][velocity].wav -- e.g., “pedalU2.wav” => pedal release (U = up), velocity = 2 (quicker release than velocity = 1).
  This dataset is too large to download directly from this item page. You can access and download the data via Globus (See https://www.youtube.com/watch?v=uf2c7Y1fiFs for instructions on how to use Globus)."
  end
  let(:ark) { "ark:/88435/dsp015999n653h" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/r75s-9j74" }

  before do
    page.driver.browser.manage.window.resize_to(2000, 2000)
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
      find("#rights_identifier").find(:xpath, "option[3]").select_option
      fill_in "given_name_1", with: "Daniel"
      fill_in "family_name_1", with: "Trueman"
      click_on "v-pills-additional-tab"
      fill_in "contributor_given_name_1", with: "Matthew"
      fill_in "contributor_family_name_1", with: "Wang"
      find("#contributor_role_1").find(:xpath, "option[2]").select_option
      click_on "Add Another Contributor"
      fill_in "contributor_given_name_2", with: "Andrés"
      fill_in "contributor_family_name_2", with: "Villalta"
      find("#contributor_role_2").find(:xpath, "option[2]").select_option
      click_on "Add Another Contributor"
      fill_in "contributor_given_name_3", with: "Katie"
      fill_in "contributor_family_name_3", with: "Chou"
      find("#contributor_role_3").find(:xpath, "option[2]").select_option
      click_on "Add Another Contributor"
      fill_in "contributor_given_name_4", with: "Christien"
      fill_in "contributor_family_name_4", with: "Ayres"
      find("#contributor_role_4").find(:xpath, "option[2]").select_option
      click_on "v-pills-curator-controlled-tab"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2021
      find("#collection_id").find(:xpath, "option[1]").select_option
      click_on "v-pills-curator-controlled-tab"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      bitklavier_work = Work.last
      expect(bitklavier_work.title).to eq title

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(bitklavier_work)
      expect(datacite.valid?).to eq true
      export_spec_data("bitKlavier-binaural.json", bitklavier_work.to_json)
    end
  end
end
