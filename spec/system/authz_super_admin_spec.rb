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
      stub_s3
      sign_in submitter2
      visit user_path(submitter2)
      expect(page).to have_content submitter2.given_name
      click_on "Submit New"
      fill_in "title_main", with: title1

      fill_in "creators[][given_name]", with: FFaker::Name.first_name
      fill_in "creators[][family_name]", with: FFaker::Name.last_name
      click_on "Create New"
      fill_in "description", with: FFaker::Lorem.paragraph
      select "GNU General Public License", from: "rights_identifier"
      click_on "Curator Controlled"
      expect(page).to have_content "Research Data"
      click_on "Save Work"
      path = Rails.root.join("spec", "fixtures", "files", "orcid.csv")
      attach_file(path) do
        page.find("#patch_readme_file").click
      end
      click_on "Continue"
      page.find(:xpath, "//input[@value='file_other']").choose
      click_on "Continue"
      click_on "Continue"
      click_on "Complete"

      expect(page).to have_content "awaiting_approval"
      work = Work.last
      allow(Work).to receive(:find).with(work.id).and_return(work)
      allow(Work).to receive(:find).with(work.id.to_s).and_return(work)
      allow(work).to receive(:publish_precurated_files).and_return(true)

      sign_out submitter2
      sign_in super_admin

      visit edit_work_path(work)
      fill_in "title_main", with: title3
      click_on "Save Work"
      expect(page).to have_content(title3)
    end

    it "should be able to edit a group to add curators and submitters" do
      group = FactoryBot.create(:group) # any random group
      sign_in super_admin
      visit edit_group_path(group)
      expect(page).to have_content "Add Submitter"
      expect(page).to have_content "Add Moderator"
      fill_in "group_title", with: title3
      click_on "Update Group"
      expect(current_path).to eq group_path(group)
      expect(page).to have_content title3
    end

    it "should be able to approve a work" do
      stub_datacite_doi
      stub_s3 data: [FactoryBot.build(:s3_file)]
      work = FactoryBot.create :awaiting_approval_work

      work.save!
      work.reload
      allow(Work).to receive(:find).with(work.id).and_return(work)
      allow(Work).to receive(:find).with(work.id.to_s).and_return(work)
      allow(work).to receive(:publish_precurated_files).and_return(true)

      sign_in super_admin
      visit work_path(work)
      click_on "Approve Dataset"
      expect(page).to have_content "marked as Approved"
    end
  end
end
