# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating bitklavier", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "bitKlavier Grand Sample Library—Binaural Mic Image" }
  let(:description) do
    "The bitKlavier Grand consists of sample collections of a new Steinway D grand piano from nine different stereo mic images, with: 16 velocity layers, at every minor 3rd (starting at A0); Hammer release samples; Release resonance samples; Pedal samples. Release packages at 96k/24bit, 88.2k/24bit, 48k/24bit, 44.1k/16bit are available for various applications. Binaural: Neumann KU100 This is the binaural head placed in the same location as a seated pianist. It accurately captures what the player would hear while playing the instrument. File Naming Convention: C4 = middle C. Main note names: [note name][octave]v[velocity].wav -- e.g., “D#5v13.wav”. Release resonance notes: harm[note name][octave]v[velocity].wav -- e.g., “harmC2v2.wav”. Hammer samples: rel[1-88].wav (one per key) -- e.g., “rel23.wav”. Pedal samples: pedal[D/U][velocity].wav -- e.g., “pedalU2.wav” => pedal release (U = up), velocity = 2 (quicker release than velocity = 1)."
  end
  let(:ark) { "ark:/88435/dsp01nv9356017" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/zztk-f783" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/zztk-f783")
      .to_return(status: 200, body: "", headers: {})
    stub_s3
  end
  context "migrate record from dataspace" do
    it "produces and saves a valid datacite record" do
      sign_in user
      visit "/works/new?migrate=true"
      fill_in "title_main", with: title
      fill_in "description", with: description
      select "Creative Commons Attribution 4.0 International", from: "rights_identifiers"
      find("tr:last-child input[name='creators[][given_name]']").set "Daniel"
      find("tr:last-child input[name='creators[][family_name]']").set "Trueman"
      click_on "Additional Metadata"
      find("tr:last-child input[name='contributors[][given_name]']").set "Matthew"
      find("tr:last-child input[name='contributors[][family_name]']").set "Wang"
      find("tr:last-child select[name='contributors[][role]']").find(:option, "Contact Person").select_option
      click_on "Add Another Individual Contributor"
      find("tr:last-child input[name='contributors[][given_name]']").set "Andrés"
      find("tr:last-child input[name='contributors[][family_name]']").set "Villalta"
      find("tr:last-child select[name='contributors[][role]']").find(:option, "Contact Person").select_option
      click_on "Add Another Individual Contributor"
      find("tr:last-child input[name='contributors[][given_name]']").set "Katie"
      find("tr:last-child input[name='contributors[][family_name]']").set "Chou"
      find("tr:last-child select[name='contributors[][role]']").find(:option, "Contact Person").select_option
      click_on "Add Another Individual Contributor"
      find("tr:last-child input[name='contributors[][given_name]']").set "Christien"
      find("tr:last-child input[name='contributors[][family_name]']").set "Ayres"
      find("tr:last-child select[name='contributors[][role]']").find(:option, "Contact Person").select_option
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2021
      select "Research Data", from: "group_id"
      click_on "Curator Controlled"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      bitklavier_work = Work.last
      expect(bitklavier_work.title).to eq title
      expect(bitklavier_work.ark).to eq ark

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(bitklavier_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/bitklavier.xml"))
      export_spec_data("bitKlavier-binaural.json", bitklavier_work.to_json)
    end
  end
end
