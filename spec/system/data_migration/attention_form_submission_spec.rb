# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating attention", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Attention and awareness in the dorsal attention network" }
  let(:description) do
    "The attention schema theory (AST) posits a specific relationship between subjective awareness and attention, in which awareness is the control model that the brain uses to aid in the endogenous control of attention. We proposed that the right temporoparietal junction (TPJ) is involved in that interaction between awareness and attention. In previous experiments, we developed a behavioral paradigm in human subjects to manipulate awareness and attention. The paradigm involved a visual cue that could be used to guide a shift of attention to a target stimulus. In task 1, subjects were aware of the visual cue, and their endogenous control mechanism was able to use the cue to help control attention. In task 2, subjects were unaware of the visual cue, and their endogenous control mechanism was no longer able to use it to control attention, even though the cue still had a measurable effect on other aspects of behavior. Here we tested the two tasks while scanning brain activity in human volunteers. We predicted that the right TPJ would be active in relation to the cue in task 1, but not in task 2. This prediction was confirmed. The right TPJ was active in relation to the cue in task 1; it was not measurably active in task 2; the difference was significant. In our interpretation, the right TPJ is involved in a complex interaction in which awareness aids in the control of attention. This dataset contains structural and functional MRI images from human subjects learning to use subliminal and superliminal stimuli to perform a Posner-like reaction time task. Download the README.txt file for a detailed description of this dataset's content"
  end
  let(:ark) { "ark:/88435/dsp01xp68kk27p" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/9425-b553" }
  let(:file_upload) { Pathname.new(fixture_path).join("dataspace_migration", "attention", "Attention_Awareness_Dorsal_Attention_README.txt").to_s }
  let(:file1) { FactoryBot.build :s3_file, filename: file_upload }
  let(:bucket_url) do
    "https://example-bucket.s3.amazonaws.com/"
  end

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/9425-b553")
      .to_return(status: 200, body: "", headers: {})
    stub_request(:put, /#{bucket_url}/).to_return(status: 200)
    stub_s3(data: [file1])
  end
  context "migrate record from dataspace" do
    it "produces and saves a valid datacite record" do
      sign_in user
      visit "/works/new"
      fill_in "title_main", with: title
      fill_in "description", with: description
      select "Creative Commons Attribution 4.0 International", from: "rights_identifier"
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

      click_on "Additional Metadata"

      ## Funder Information
      # An example of a funder who does not have an ROR
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][funder_name]']").set "Princeton Neuroscience Institute Innovation Fund"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "PRINU-24400-G0002-10005089-101"

      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2020
      select "Research Data", from: "collection_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      page.attach_file("work[pre_curation_uploads_added][]", [file_upload], make_visible: true)
      click_on "Create"
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      attention_work = Work.last
      expect(attention_work.title).to eq title
      expect(attention_work.ark).to eq ark

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(attention_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/attention.xml"))
      export_spec_data("attention.json", attention_work.to_json)
    end
  end
end
