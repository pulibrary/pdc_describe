# frozen_string_literal: true
require "rails_helper"
RSpec.describe "Reports page", type: :system, js: true do
  describe "Reports page" do
    let(:moderator_user) { FactoryBot.create :pppl_moderator }
    let(:tokamak_work) { FactoryBot.create :tokamak_work }
    let(:pppl_work) { FactoryBot.create :pppl_work }
    let(:rd_work) { FactoryBot.create :approved_work }

    before do
      tokamak_work
      pppl_work
      rd_work
    end

    it "renders the reports page", js: true do
      stub_s3
      sign_in moderator_user
      visit reports_dataset_list_path
      expect(page.html.include?("View")).to be true
      expect(page.html.include?(tokamak_work.title)).to be true
      expect(page.html.include?(pppl_work.title)).to be true
      expect(page.html.include?(rd_work.title)).to be true
    end

    it "filters by group", js: true do
      stub_s3
      sign_in moderator_user
      visit reports_dataset_list_path
      select "PPPL", from: "group"
      click_on "View"
      expect(page.html.include?(tokamak_work.title)).to be true
      expect(page.html.include?(pppl_work.title)).to be true
      expect(page.html.include?(rd_work.title)).to be false
    end

    context "on the home page" do
      it "includes the current year in the link to the reports page", js: true do
        stub_s3
        sign_in moderator_user
        visit root_path
        expect(page.html.include?("#{reports_dataset_list_path}?year=#{Time.zone.now.year}")).to be true
      end
    end
  end
end
