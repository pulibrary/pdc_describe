# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Researcher List View", type: :system, js: true do
  describe "Researcher List" do
    let!(:researcher) { FactoryBot.create :researcher }
    let!(:researcher2) { FactoryBot.create :researcher }
    let(:user_admin) { FactoryBot.create :super_admin_user }

    it "shows basic information about researchers" do
      sign_in user_admin
      visit researchers_path
      expect(page.html.include?("First name")).to be true
      expect(page.html.include?("Last name")).to be true
      expect(page.html.include?("ORCID")).to be true
      expect(page.html.include?(researcher.first_name)).to be true
      expect(page.html.include?(researcher.last_name)).to be true
      expect(page.html.include?(researcher.orcid)).to be true
      expect(Researcher.count).to eq(2)
    end
  end
end
