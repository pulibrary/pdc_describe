# frozen_string_literal: true
require "rails_helper"
##
# A submitter is a logged in user with no permissions other than being able to deposit.
# One submitter should not be able to edit the work of another submitter.
RSpec.describe "Authz for super admins", type: :system, js: true do
  describe "A Super Admin" do
    let(:super_admin) { FactoryBot.create :super_admin_user }
    let(:submitter2) { FactoryBot.create :princeton_submitter }
    let(:title1) { "Title One" }
    let(:title2) { "Title Two" }
    let(:title3) { "Title Three" }

    before do
      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    end

    it "should be able to edit someone else's work" do
      sign_in submitter2
      visit user_path(submitter2)
      expect(page).to have_content submitter2.display_name
      click_on "Submit New"
      fill_in "title_main", with: title1

      fill_in "given_name_1", with: FFaker::Name.first_name
      fill_in "family_name_1", with: FFaker::Name.last_name
      click_on "Create New"
      fill_in "description", with: FFaker::Lorem.paragraph
      select "GNU General Public License", from: "rights_identifier"
      click_on "Curator Controlled"
      expect(page).to have_content "Research Data"
      click_on "Save Work"
      page.find(:xpath, "//input[@value='file_other']").choose
      click_on "Continue"
      click_on "Continue"
      click_on "Complete"

      expect(page).to have_content "awaiting_approval"
      work = Work.last
      file_name = "us_covid_2019.csv"
      stub_work_s3_requests(work: work, file_name: file_name)

      sign_out submitter2
      sign_in super_admin

      visit edit_work_path(work)
      fill_in "title_main", with: title3
      click_on "Save Work"
      expect(page).to have_content(title3)
    end

    it "should be able to edit a collection to add curators and submitters" do
      collection = FactoryBot.create(:collection) # any random collection
      sign_in super_admin
      visit edit_collection_path(collection)
      expect(page).to have_content "Add Submitter"
      expect(page).to have_content "Add Moderator"
      fill_in "collection_title", with: title3
      click_on "Update Collection"
      expect(current_path).to eq collection_path(collection)
      expect(page).to have_content title3
    end

    it "should be able to approve a work" do
      stub_datacite_doi
      work = FactoryBot.create :awaiting_approval_work

      file_name = "us_covid_2019.csv"
      stub_work_s3_requests(work: work, file_name: file_name)
      uploaded_file = fixture_file_upload(file_name, "text/csv")
      work.pre_curation_uploads.attach(uploaded_file)

      work.save!
      work.reload

      sign_in super_admin
      visit work_path(work)
      click_on "Approve Dataset"
      expect(page).to have_content "marked as Approved"
    end
  end
end
