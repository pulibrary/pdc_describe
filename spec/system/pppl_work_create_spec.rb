# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for a PPPL dataset", type: :system do
  let(:user) { FactoryBot.create(:pppl_submitter) }
  let!(:curator) { FactoryBot.create(:user, groups_to_admin: [Group.plasma_laboratory]) }
  let(:title) { "PPPL Work Test" }
  let(:contributors) do
    [
      "Abrams, Samantha"
    ]
  end
  let(:issue_date) { 2019 }
  let(:related_publication) { "Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It, Fall/Winter 2019, Vol. 82, No. 2." }
  let(:abstract) { "Testing that the form is populated correctly for a PPPL user" }
  let(:description) { "Download the README.txt for a detailed description of this dataset's content." }
  let(:ark) { "http://arks.princeton.edu/ark:/88435/dsp11122223333" }

  before do
    stub_s3
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end
  context "happy path" do
    it "produces and saves a valid datacite record", js: true do
      sign_in user
      visit work_create_new_submission_path
      fill_in "title_main", with: title
      find("tr:last-child input[name='creators[][given_name]']").set "Samantha"
      find("tr:last-child input[name='creators[][family_name]']").set "Abrams"
      click_on "Next"
      fill_in "description", with: description
      select "GNU General Public License", from: "rights_identifiers"
      click_on "Additional Metadata"
      expect(page).to have_content("Domains")
      select "Natural Sciences", from: "domains"
      expect(page).to have_content("Community")
      expect(page).to have_content("Subcommunities")
      select "NSTX", from: "subcommunities"
      expect(page).to have_field(name: "funders[][funder_name]", with: "United States Department of Energy")
      expect(page).to have_field(name: "funders[][ror]", with: "https://ror.org/01bj3aw27")
      expect(page).to have_field(name: "funders[][award_number]", with: "DE-AC02-09CH11466")
      click_on "Curator Controlled"
      expect(page).to have_field("publisher", with: "Princeton Plasma Physics Laboratory, Princeton University")
      click_on "Save Work"
      expect(page).to have_content("Please upload the README")
      expect(page).to have_button("Continue", disabled: true)
      path = Rails.root.join("spec", "fixtures", "files", "readme.txt")
      attach_file(path) do
        page.find("#patch_readme_file").click
      end
      click_on "Continue"

      # Make sure the readme is in S3 so when I hit the back button we do not error
      work = Work.last
      stub_s3 data: [FactoryBot.build(:s3_readme, work:)]

      click_on "Back"
      expect(page).to have_content("Please upload the README")
      expect(page).to have_content("README.txt was previously uploaded. You will replace it if you select a different file.")
      click_on "Continue"
      page.find(:xpath, "//input[@value='file_other']").choose
      click_on "Continue"
      click_on "Continue"
      expect(page).to have_content("In furtherance of its non-profit educational mission, Princeton University")
      click_on "Complete"

      expect(page).to have_content "awaiting_approval"
    end
  end
end
