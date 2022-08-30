# frozen_string_literal: true
require "rails_helper"
##
# A submitter is a logged in user with no permissions other than being able to deposit.
# One submitter should not be able to edit the work of another submitter.
RSpec.describe "Authz for submitters", type: :system, js: true, mock_ezid_api: true do
  describe "A submitter" do
    let(:submitter1) { FactoryBot.create :princeton_submitter }
    let(:submitter2) { FactoryBot.create :princeton_submitter }
    let(:title1) { "Title One" }
    let(:title2) { "Title Two" }
    let(:title3) { "Title Three" }

    before do
      Collection.create_defaults
      stub_s3
      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    end

    ##
    # To be fixed by https://github.com/pulibrary/pdc_describe/issues/348
    xit "should not be able to edit someone else's work" do
      sign_in submitter1
      visit user_path(submitter1)
      expect(page).to have_content submitter1.display_name
      click_on "Submit New"
      fill_in "title_main", with: title1

      fill_in "given_name_1", with: FFaker::Name.first_name
      fill_in "family_name_1", with: FFaker::Name.last_name
      click_on "Create New"
      fill_in "description", with: FFaker::Lorem.paragraph
      click_on "Additional Metadata"
      expect(page).to have_content "Research Data"
      click_on "Save Work"
      page.find(:xpath, "//input[@value='file_other']").choose
      click_on "Continue"
      click_on "Continue"
      click_on "Complete"

      expect(page).to have_content "awaiting_approval"
      work = Work.last

      # Submitter can edit their own work
      visit edit_work_path(work)
      fill_in "title_main", with: title2
      click_on "Save Work"
      sign_out submitter1
      sign_in submitter2

      visit edit_work_path(work)
      fill_in "title_main", with: title3
      click_on "Save Work"
    end

    it "should not be able to edit a collection to add curators and submitters" do
      sign_in submitter1
      visit collection_path(submitter1.default_collection)
      expect(page).not_to have_content "Add Submitter"
      expect(page).not_to have_content "Add Curator"
      visit edit_collection_path(submitter1.default_collection)
      expect(page).not_to have_content "Update Collection"
      expect(current_path).to eq "/collections"
    end
  end
end
