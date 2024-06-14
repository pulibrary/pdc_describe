# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Work Approval", type: :system do
  let(:work) { FactoryBot.create(:awaiting_approval_work) }
  let!(:curator) { FactoryBot.create(:user, groups_to_admin: [work.group]) }

  before do
    stub_s3
    stub_ark
    stub_datacite_doi
  end
  context "No uploads, can not approve" do
    it "produces and saves a valid datacite record", js: true do
      sign_in curator
      visit(user_path(curator))
      expect(page).to have_content curator.given_name
      click_link work.title
      expect(page).to have_content(work.doi)
      click_on "Approve Dataset"
      page.driver.browser.switch_to.alert.accept
      expect(page).to have_content("You must include at least one file. Please upload one.")
    end

    it "does not display warning if user cancels approval", js: true do
      sign_in curator
      visit(user_path(curator))
      expect(page).to have_content curator.given_name
      click_link work.title
      expect(page).to have_content(work.doi)
      click_on "Approve Dataset"
      sleep(0.5)
      page.driver.browser.switch_to.alert.dismiss
      expect(page).not_to have_content("You must include at least one file. Please upload one.")
    end
  end
end
