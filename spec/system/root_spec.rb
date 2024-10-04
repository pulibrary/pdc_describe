# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WelcomeController" do
  it "visits the root", js: true do
    visit "/"

    expect(page).to have_content "Welcome"
  end

  context "when requesting a URL which does not exist", type: :system do
    it "renders the custom 404 page" do
      visit "/invalid"

      expect(page.status_code).to eq(404)
      expect(page).to have_content "The page you were looking for doesn't exist."
    end
  end

  context "when an error occurs while requesting a URL", type: :system do
    let(:user) { FactoryBot.create(:super_admin_user) }
    let(:work) { FactoryBot.create(:draft_work) }

    before do
      sign_in(user)
      work
      allow(Work).to receive(:find).and_raise(StandardError, "test")
    end

    it "renders the custom 500 page" do
      visit "/works/#{work.id}"

      expect(page.status_code).to eq(500)
      expect(page).to have_content("We apologize, an error was encountered: test")
    end
  end
end
