# frozen_string_literal: true
require "rails_helper"

describe "header", type: :system do
  context "for logged-out users" do
    it "renders the correct links on homepage" do
      visit "/"
      expect(page).to have_link("Princeton Data Commons: Discovery", href: "https://datacommons.princeton.edu/discovery/")
      expect(page).to have_selector(:link_or_button, "How to Submit")
      expect(page).to have_selector(:link_or_button, "Need Help?")
      expect(page).to have_selector(:link_or_button, "Log In")
    end

    it "renders the correct links on help page" do
      visit "/help"
      expect(page).to have_link("Princeton Data Commons: Discovery", href: "https://datacommons.princeton.edu/discovery/")
      expect(page).to have_selector(:link_or_button, "How to Submit")
      expect(page).to have_selector(:link_or_button, "Need Help?")
      expect(page).to have_selector(:link_or_button, "Log In")
    end
  end

  context "for logged-in users" do
    let(:user) { FactoryBot.create :princeton_submitter }

    before do
      login_as user
    end

    it "renders the correct links on homepage" do
      visit "/"
      expect(page).to have_selector(:link_or_button, "How to Submit")
      expect(page).to have_selector(:link_or_button, "Need Help?")
      expect(page).to have_selector(:link_or_button, user.uid.to_s)
    end

    it "renders the correct links on help page" do
      visit "/help"
      expect(page).to have_selector(:link_or_button, "How to Submit")
      expect(page).to have_selector(:link_or_button, "Need Help?")
      expect(page).to have_selector(:link_or_button, user.uid.to_s)
    end

    it "renders the correct links on notifications page" do
      visit "/work_activity_notifications"
      expect(page).to have_selector(:link_or_button, "How to Submit")
      expect(page).to have_selector(:link_or_button, "Need Help?")
      expect(page).to have_selector(:link_or_button, user.uid.to_s)
    end

    it "renders the correct links on profile page" do
      visit "/users/#{user.uid}/edit"
      expect(page).to have_selector(:link_or_button, "How to Submit")
      expect(page).to have_selector(:link_or_button, "Need Help?")
      expect(page).to have_selector(:link_or_button, user.uid.to_s)
    end

    it "renders the correct links on dashboard page" do
      visit "users/#{user.uid}"
      expect(page).to have_selector(:link_or_button, "How to Submit")
      expect(page).to have_selector(:link_or_button, "Need Help?")
      expect(page).to have_selector(:link_or_button, user.uid.to_s)
    end
  end
end
