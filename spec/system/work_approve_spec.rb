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
      expect(page).to have_content("Uploads must be present for a work to be approved")
    end
  end
end
