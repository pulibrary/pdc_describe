# frozen_string_literal: true
require "rails_helper"

describe "walk the wizard hitting all the buttons", type: :system, js: true do
  let(:user) { FactoryBot.create :princeton_submitter }
  it "allows me to stay on each page and then move forward" do
    sign_in user
    stub_datacite
    stub_s3

    visit work_policy_path
    expect(page).to have_css("form[action='/works/policy']")
    check "agreement"
    expect { click_on "Confirm" }.to change { Work.count }.by(1)
    work = Work.last

    expect(page).to have_css("form[action='/works/#{work.id}/new-submission']")
    fill_in "title_main", with: "title"
    click_on "Add me as a Creator"
    expect(find("tr:last-child input[name='creators[][given_name]']").value).to eq(user.given_name)
    expect(find("tr:last-child input[name='creators[][family_name]']").value).to eq(user.family_name)
    click_on "Create New"

    edit_form_css = "form[action='/works/#{work.id}/update-wizard']"
    additional_form_css = "form[action='/works/#{work.id}/update-additional']"
    readme_form_css = "form[action='/works/#{work.id}/readme-uploaded']"
    upload_form_css = "form[action='/works/#{work.id}/attachment-select']"
    file_upload_form_css = "form[action='/works/#{work.id}/file-upload']"
    validate_form_css = "form[action='/works/#{work.id}/validate-wizard']"

    # edit form has no previous button so no need to test that it goes back
    expect(page).not_to have_content("Previous")
    expect(page).to have_css(edit_form_css)
    fill_in "description", with: "description"

    # change the name entered
    updated_name = user.given_name + "2"
    fill_in "creators[][given_name]", with: updated_name

    expect { click_on "Save" }.to change { work.work_activity.count }.by(1)

    # make sure we render the updated name after the save
    expect(page.html.include?(updated_name)).to be true

    expect(page).to have_css(edit_form_css)
    click_on "Next"

    expect(page).to have_css(additional_form_css)
    click_on "Previous"
    expect(page).to have_css(edit_form_css)
    click_on "Next"
    expect(page).to have_css(additional_form_css)
    click_on "Next"

    expect(page).to have_css(readme_form_css)
    expect(page).not_to have_content("previously uploaded")

    click_on "Previous"
    expect(page).to have_css(additional_form_css)
    click_on "Next"
    expect(page).to have_css(readme_form_css)
    stub_s3 data: [FactoryBot.build(:s3_readme, work:)]
    click_on "Save"
    expect(page).to have_css(readme_form_css)
    expect(page).to have_content("previously uploaded")
    click_on "Next"
    expect(page).to have_css(upload_form_css)

    click_on "Previous"
    expect(page).to have_css(readme_form_css)
    click_on "Next"
    expect(work.reload.files_location).to be_nil
    expect(page).to have_css(upload_form_css)
    page.find(:xpath, "//input[@value='file_upload']").choose
    click_on "Save"
    expect(work.reload.files_location). to eq("file_upload")
    expect(page).to have_css(upload_form_css)
    click_on "Next"
    expect(page).to have_css(file_upload_form_css)

    click_on "Previous"
    expect(page).to have_css(upload_form_css)
    click_on "Next"
    expect(page).to have_css(file_upload_form_css)
    click_on "Save"
    sleep(1) # no actual upload occured so no real change to be seen
    expect(page).to have_css(file_upload_form_css)

    # The README file is displayed but cannot be deleted
    expect(page).to have_content("README.txt")
    expect(page).to_not have_content("Delete file")

    click_on "Next"
    expect(page).to have_css(validate_form_css)
    # Force the work to have two files (readme + another file)
    stub_s3 data: [FactoryBot.build(:s3_readme, work:), FactoryBot.build(:s3_file, work:)]

    click_on "Previous"
    expect(page).to have_css(file_upload_form_css)
    click_on "Next"
    expect(page).to have_css(validate_form_css)
    fill_in "submission_notes", with: "this is not on the page"
    click_on "Save"
    expect(work.reload.submission_notes). to eq("this is not on the page")
    expect(page).to have_css(validate_form_css)
    expect(page).to have_content("this is not on the page")
    click_on "Grant License and Complete"
    page.driver.browser.switch_to.alert.accept
    expect(page).to have_content("5-10 business days")
  end

  context "User submits their work" do
    before do
      stub_s3
    end

    it "displays confirm dialogue when user grants license", js: true do
      sign_in user
      work = FactoryBot.create :draft_work
      visit work_review_path(work)
      click_on "Grant License and Complete"
      page.driver.browser.switch_to.alert.accept
      expect(page).to have_content("Welcome")
    end
    it "remains on the same page if cancel is clicked", js: true do
      sign_in user
      work = FactoryBot.create :draft_work
      visit work_review_path(work)
      click_on "Grant License and Complete"
      page.driver.browser.switch_to.alert.dismiss
      expect(page).to have_content("New Submission")
    end
  end

  context "file is in another location" do
    it "allows me to stay on each page and then move forward" do
      sign_in user
      work = FactoryBot.create :draft_work
      stub_s3 data: [FactoryBot.build(:s3_readme, work:)]
      visit work_attachment_select_path(work)
      other_form_css = "form[action='/works/#{work.id}/review']"
      upload_form_css = "form[action='/works/#{work.id}/attachment-select']"
      validate_form_css = "form[action='/works/#{work.id}/validate-wizard']"

      page.find(:xpath, "//input[@value='file_other']").choose
      click_on "Save"
      expect(work.reload.files_location). to eq("file_other")
      expect(page).to have_css(upload_form_css)
      click_on "Next"
      expect(page).to have_css(other_form_css)

      click_on "Previous"
      expect(page).to have_css(upload_form_css)
      click_on "Next"
      expect(page).to have_css(other_form_css)
      fill_in "location_notes", with: "this is not on the page"
      click_on "Save"
      expect(work.reload.location_notes). to eq("this is not on the page")
      expect(page).to have_css(other_form_css)
      click_on "Next"
      expect(page).to have_css(validate_form_css)
    end
  end

  context "user bails out of the wizard after record has been created on the database" do
    it "handles an abandoned work properly" do
      sign_in user
      stub_datacite
      visit work_policy_path
      check "agreement"
      click_on "Confirm"
      work = Work.last

      # Emulate the user completelly abandoning the wizard
      visit user_path(user)

      # Force the user back to the wizard (rather than to the Show page)
      expect(page.html.include?("(untitled)")).to be true
      expect(page.html.include?("/works/#{work.id}/new-submission")).to be true
    end
  end
end
