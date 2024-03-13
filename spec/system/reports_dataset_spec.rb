# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Reports page", type: :system, js: true do
  describe "Reports page" do
    let(:moderator_user) { FactoryBot.create :pppl_moderator }
    let(:tokamak_work) { FactoryBot.create :tokamak_work }
    let(:pppl_work) { FactoryBot.create :pppl_work }
    before do
      tokamak_work
      pppl_work
    end

    it "renders the reports page", js: true do
      sign_in moderator_user
      visit reports_dataset_list_path
      expect(page.html.include?("View")).to be true
      expect(page.html.include?(tokamak_work.title)).to be true
      expect(page.html.include?(pppl_work.title)).to be true
    end
  end
end
