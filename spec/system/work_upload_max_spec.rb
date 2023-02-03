# frozen_string_literal: true
require "rails_helper"

RSpec.describe "File selection", type: :system do
  let(:work) { FactoryBot.create :draft_work }
  let(:user) { work.created_by_user }
  before do
    # Make the screen larger so the save button is alway on screen. This avoids random `Element is not clickable` errors
    page.driver.browser.manage.window.resize_to(2000, 2000)
  end
  it "errors when more than 20 files are attached in the wizard", js: true do
    sign_in user
    visit work_file_upload_path(work)
    paths = (0..20).map { Rails.root.join("spec", "fixtures", "files", "orcid.csv") }
    attach_file(paths) do
      page.find("#patch_pre_curation_uploads").click
    end

    expect(page).to have_content("You can select a maximum of 20 files")

    paths = (0..19).map { Rails.root.join("spec", "fixtures", "files", "orcid.csv") }
    attach_file(paths) do
      page.find("#patch_pre_curation_uploads").click
    end
    expect(page).not_to have_content("You can select a maximum of 20 files")
  end

  it "errors when more than 20 files are attached on the work edit", js: true do
    sign_in user
    visit edit_work_path(work)
    paths = (0..20).map { Rails.root.join("spec", "fixtures", "files", "orcid.csv") }
    attach_file(paths) do
      page.find("#pre_curation_uploads").click
    end

    expect(page).to have_content("You can select a maximum of 20 files")

    paths = (0..19).map { Rails.root.join("spec", "fixtures", "files", "orcid.csv") }
    attach_file(paths) do
      page.find("#pre_curation_uploads").click
    end
    expect(page).not_to have_content("You can select a maximum of 20 files")
  end
end
