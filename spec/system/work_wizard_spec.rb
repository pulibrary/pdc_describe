# frozen_string_literal: true
require "rails_helper"

describe "walk the wizard hitting all the buttons", type: :system, js: true do
  let(:user) { FactoryBot.create :princeton_submitter }
  it "allows me to stay on each page and then move forward" do
    sign_in user

    visit work_create_new_submission_path
    expect(page).to have_css("form[action='/works/new-submission']")
    fill_in "title_main", with: "title"
    click_on "Add me as a Creator"
    expect(find("tr:last-child input[name='creators[][given_name]']").value).to eq(user.given_name)
    expect(find("tr:last-child input[name='creators[][family_name]']").value).to eq(user.family_name)
    click_on "Save"

    work = Work.last
    new_submission_form_css = "form[action='/works/new-submission/#{work.id}']"
    edit_form_css = "form[action='/works/#{work.id}/update-wizard']"
    readme_form_css = "form[action='/works/#{work.id}/readme-uploaded']"
    upload_form_css = "form[action='/works/#{work.id}/attachment-select']"
    file_upload_form_css = "form[action='/works/#{work.id}/file-upload']"

    expect(page).to have_css(new_submission_form_css)
    click_on "Next"

    expect(page).to have_css(edit_form_css)

    click_on "Previous"
    expect(page).to have_css(new_submission_form_css)

    click_on "Next"
    expect(page).to have_css(edit_form_css)

    fill_in "description", with: "description"

    expect { click_on "Save" }.to change { work.work_activity.count }.by(1)
    expect(page).to have_css(edit_form_css)

    click_on "Next"
    expect(page).to have_css(readme_form_css)
    expect(page).not_to have_content("previously uploaded")

    click_on "Previous"
    expect(page).to have_css(edit_form_css)

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
    expect(page).to have_css(upload_form_css)

    click_on "Save"
    sleep(1)
    expect(page).to have_css(upload_form_css)

    click_on "Next"
    expect(page).to have_css(file_upload_form_css)
  end
end
