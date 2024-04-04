# frozen_string_literal: true
require "rails_helper"

describe "walk the wizard in reverse", type: :system, js: true do
  it "follow the same path in reverse or forward" do
    work = FactoryBot.create :draft_work, files_location: "file_upload"
    stub_s3 data: [FactoryBot.build(:s3_readme, work:)]
    sign_in work.created_by_user
    visit work_review_path(work)

    expect(page).to have_content "Data curators will review"
    click_on "Previous"

    expect(page).to have_content "Once you have uploaded"
    click_on "Previous"

    expect(page).to have_content "Begin the process to upload your submission"
    click_on "Previous"

    expect(page).to have_content "Please upload the README"
    click_on "Previous"

    expect(page).to have_content "By initiating this new submission"
    click_on "Next"

    expect(page).to have_content("These metadata properties are not required")  #testing additional metadata page
    click_on "Next"

    expect(page).to have_content "Please upload the README"
    click_on "Next"

    expect(page).to have_content "Begin the process to upload your submission"
    click_on "Next"

    expect(page).to have_content "Once you have uploaded"
    click_on "Next"

    expect(page).to have_content "Data curators will review"
  end
end
