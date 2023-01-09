# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating attention", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Attention and awareness in the dorsal attention network" }
  let(:description) do
    "The attention schema theory (AST) posits a specific relationship between subjective awareness and attention, in which awareness is the control model that the brain uses to aid in the endogenous control of attention. We proposed that the right temporoparietal junction (TPJ) is involved in that interaction between awareness and attention. In previous experiments, we developed a behavioral paradigm in human subjects to manipulate awareness and attention. The paradigm involved a visual cue that could be used to guide a shift of attention to a target stimulus. In task 1, subjects were aware of the visual cue, and their endogenous control mechanism was able to use the cue to help control attention. In task 2, subjects were unaware of the visual cue, and their endogenous control mechanism was no longer able to use it to control attention, even though the cue still had a measurable effect on other aspects of behavior. Here we tested the two tasks while scanning brain activity in human volunteers. We predicted that the right TPJ would be active in relation to the cue in task 1, but not in task 2. This prediction was confirmed. The right TPJ was active in relation to the cue in task 1; it was not measurably active in task 2; the difference was significant. In our interpretation, the right TPJ is involved in a complex interaction in which awareness aids in the control of attention. This dataset contains structural and functional MRI images from human subjects learning to use subliminal and superliminal stimuli to perform a Posner-like reaction time task. Download the README.txt file for a detailed description of this dataset's content

This dataset is too large to download directly from this item page. You can access and download the data via Globus at this link:https://app.globus.org/file-manager?origin_id=dc43f461-0ca7-4203-848c-33a9fc00a464&origin_path=%2F9425-b553%2F (See https://docs.globus.org/how-to/get-started/ for instructions on how to use Globus, sign-in is required)."
  end
  let(:ark) { "ark:/88435/dsp01xp68kk27p" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/9425-b553" }

  before do
    page.driver.browser.manage.window.resize_to(2000, 2000)
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/9425-b553")
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
      fill_in "given_name_1", with: "Andrew"
      fill_in "family_name_1", with: "Wilterson"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "Samuel"
      fill_in "family_name_2", with: "Nastase"
      click_on "Add Another Creator"
      fill_in "given_name_3", with: "Branden"
      fill_in "family_name_3", with: "Bio"
      click_on "Add Another Creator"
      fill_in "given_name_4", with: "Arvid"
      fill_in "family_name_4", with: "Guterstam"
      click_on "Add Another Creator"
      fill_in "given_name_5", with: "Michael"
      fill_in "family_name_5", with: "Graziano"
      click_on "v-pills-curator-controlled-tab"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2020
      find("#collection_id").find(:xpath, "option[1]").select_option
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      attention_work = Work.last
      expect(attention_work.title).to eq title

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(attention_work)
      expect(datacite.valid?).to eq true
    end
  end
end
