# frozen_string_literal: true
require "rails_helper"
RSpec.describe "User dashboard", type: :system, js: true do
  describe "Sort by last edited uses the proper value" do
    let(:user_admin) { FactoryBot.create :super_admin_user }
    let(:work) { FactoryBot.create(:draft_work) }
    let(:moderator_user) { FactoryBot.create :pppl_moderator }

    it "renders the proper date value for sorting by last edited", js: true do
      work_last_edited = work.updated_at.to_s
      sign_in user_admin
      visit user_path(user_admin)
      expect(page).to have_css('td.last-edited[data-sort="' + work_last_edited + '"]')
    end

    it "renders the group names as links", js: true do
      sign_in moderator_user
      visit user_path(moderator_user)
      pppl_url = group_path(Group.plasma_laboratory)
      expected_link = "<a href=\"#{pppl_url}\">#{Group.plasma_laboratory.title}</a>"
      expect(page.html.include?(expected_link)).to be true
    end
  end

  describe "Search feature" do
    let(:pppl_moderator) { FactoryBot.create :pppl_moderator }
    let(:rd_moderator) { FactoryBot.create :research_data_moderator }
    let(:user_admin) { FactoryBot.create :super_admin_user }

    before do
      FactoryBot.create(:tokamak_work)
      FactoryBot.create(:shakespeare_and_company_work)
    end

    it "finds works for the user logged in", js: true do
      sign_in pppl_moderator
      visit user_path(pppl_moderator) + "?q=tokamak"
      expect(page.html.include?("Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas")).to be true
      expect(page.html.include?("Shakespeare and Company Project Dataset: Lending Library Members, Books, Events")).to be false

      sign_in rd_moderator
      visit user_path(rd_moderator) + "?q=shakespeare"
      expect(page.html.include?("Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas")).to be false
      expect(page.html.include?("Shakespeare and Company Project Dataset: Lending Library Members, Books, Events")).to be true
    end

    it "allows administrators to find works regardless of the group" do
      sign_in user_admin
      visit user_path(user_admin) + "?q=shakespeare"
      expect(page.html.include?("Shakespeare and Company Project Dataset: Lending Library Members, Books, Events")).to be true
      visit user_path(user_admin) + "?q=tokamak"
      expect(page.html.include?("Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas")).to be true
    end

    it "shows no results found" do
      sign_in user_admin
      visit user_path(user_admin) + "?q=gobbledygook"
      expect(page.html.include?("No works found")).to be true
    end

    it "searches within several fields inside the work" do
      sign_in rd_moderator

      # search within the DOI
      visit user_path(rd_moderator) + "?q=10.34770/pe9w-x904"
      expect(page.html.include?("Shakespeare and Company")).to be true

      # search within the ARK
      visit user_path(rd_moderator) + "?q=ark:/88435/dsp01zc77st047"
      expect(page.html.include?("Shakespeare and Company")).to be true

      # search within the description
      visit user_path(rd_moderator) + "?q=Sylvia Beach"
      expect(page.html.include?("Shakespeare and Company")).to be true

      # search within the creators
      visit user_path(rd_moderator) + "?q=Kotin"
      expect(page.html.include?("Shakespeare and Company")).to be true
    end
  end

  describe "User List" do
    let(:user_admin) { FactoryBot.create :super_admin_user }

    before do
      FactoryBot.create :pppl_moderator
      FactoryBot.create :research_data_moderator
    end

    it "shows basic information about users" do
      sign_in user_admin
      visit users_path
      expect(page.html.include?("Net ID")).to be true
      expect(page.html.include?("Given name")).to be true
      expect(page.html.include?("ORCID")).to be true
      expect(page.html.include?(user_admin.uid)).to be true
    end
  end
  describe "dashboard shows finished and unfinished works" do
    let(:user_admin) { FactoryBot.create :super_admin_user }
    before do
      FactoryBot.create :draft_work
      FactoryBot.create :approved_work
    end
    it "shows the number of finished and unfinished works" do
      sign_in user_admin
      visit user_path(user_admin)
      within("h2.unfinished-submission") do
        expect(page.text).to eq("1 Unfinished Submission")
      end
      within("h2.completed-submission") do
        expect(page.text).to eq("1 Completed Submission")
      end
    end
  end
end
