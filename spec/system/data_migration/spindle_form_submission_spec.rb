# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating Sleeo spindle", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Sleep spindle refractoriness segregates periods of memory reactivation" }
  let(:description) do
    "The stability of long-term memories is enhanced by reactivation during sleep. Correlative evidence has linked memory reactivation with thalamocortical sleep spindles, although their functional role is not fully understood. Our initial study replicated this correlation and also demonstrated a novel rhythmicity to spindles, such that a spindle is more likely to occur approximately 3–6 s following a prior spindle. We leveraged this rhythmicity to test the role of spindles in memory by using real-time spindle tracking to present cues within versus just after the presumptive refractory period; as predicted, cues presented just after the refractory period led to better memory. Our findings demonstrate a precise temporal link between sleep spindles and memory reactivation. Moreover, they reveal a previously undescribed neural mechanism whereby spindles may segment sleep into two distinct substates: prime opportunities for reactivation and gaps that segregate reactivation events."
  end
  let(:ark) { "ark:/88435/dsp011z40kw63j" }
  let(:group) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/qyrs-vg25" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/qyrs-vg25")
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
      fill_in "orcid_1", with: ""
      fill_in "given_name_1", with: "James W."
      fill_in "family_name_1", with: "Antony"
      click_on "Add Another Creator"
      fill_in "orcid_2", with: ""
      fill_in "given_name_2", with: "Luis"
      fill_in "family_name_2", with: "Piloto"
      click_on "Add Another Creator"
      fill_in "orcid_3", with: ""
      fill_in "given_name_3", with: "Margaret"
      fill_in "family_name_3", with: "Wang"
      click_on "Add Another Creator"
      fill_in "orcid_4", with: ""
      fill_in "given_name_4", with: "Paula P."
      fill_in "family_name_4", with: "Brooks"
      click_on "Add Another Creator"
      fill_in "orcid_5", with: ""
      fill_in "given_name_5", with: "Kenneth A"
      fill_in "family_name_5", with: "Norman"
      click_on "Add Another Creator"
      fill_in "orcid_6", with: ""
      fill_in "given_name_6", with: "Ken A"
      fill_in "family_name_6", with: "Paller"
      click_on "Additional Metadata"
      # Select Additional Metadata Tab
      click_on "Additional Metadata"
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2018
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      select group, from: "group_id"
      click_on "Create"
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      spindle_work = Work.last
      expect(spindle_work.title).to eq title
      expect(spindle_work.group).to eq Group.research_data
      expect(spindle_work.ark).to eq ark
      export_spec_data("spindle.json", spindle_work.to_json)

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(spindle_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/spindle.xml"))
    end
  end
end
