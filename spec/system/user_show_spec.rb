# frozen_string_literal: true
require "rails_helper"
RSpec.describe "User dashboard" do
  describe "Sort by last edited uses the proper value" do
    let(:user_admin) { FactoryBot.create :super_admin_user }
    let(:work) { FactoryBot.create(:draft_work) }
    let(:moderator_user) { FactoryBot.create :pppl_moderator }

    it "renders the proper date value for sorting by last edited", js: true do
      work_last_edited = work.updated_at.strftime("%Y-%m-%d %H:%M:%S %Z")
      sort_value = '<td class="last-edited" data-sort="' + work_last_edited + '">'
      sign_in user_admin
      visit user_path(user_admin)
      expect(page.html.include?(sort_value)).to be true
    end

    it "renders the collection names as links", js: true do
      sign_in moderator_user
      visit user_path(moderator_user)
      pppl_url = capybara_root_url + collection_path(Collection.plasma_laboratory)
      expected_link = "<a href=\"#{pppl_url}\">#{Collection.plasma_laboratory.title}</a>"
      expect(page.html.include?(expected_link)).to be true
    end
  end
end
