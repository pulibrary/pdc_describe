# frozen_string_literal: true
require "rails_helper"
RSpec.describe "User dashboard" do
  describe "Sort by last edited uses the proper value" do
    let(:user_admin) { FactoryBot.create :super_admin_user }
    let(:work) { FactoryBot.create(:draft_work) }

    it "renders the proper date value for sorting by last edited", js: true do
      work_last_edited = work.updated_at.strftime("%Y-%m-%d %H:%M:%S %Z")
      sort_value = '<td class="last-edited" data-sort="' + work_last_edited + '">'
      sign_in user_admin
      visit user_path(user_admin)
      expect(page.html.include?(sort_value)).to be true
    end
  end
end
