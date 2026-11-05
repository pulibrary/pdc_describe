# frozen_string_literal: true
require "rails_helper"

describe "/", type: :system do
  let(:user) { FactoryBot.create :user }
  let(:super_admin_user) { FactoryBot.create :super_admin_user }
  let(:research_data_moderator) { FactoryBot.create(:research_data_moderator) }

  it "renders the homepage" do
    visit "/"
    expect(page).to have_text("Welcome to Princeton Data Commons: Describe")
    expect(page).to have_text("Who can submit to this repository?")
    expect(page).to have_text("How to Submit")
    expect(page).to have_text("The review process typically takes 5-10 business days")
  end

  context "entra message enabled" do
      let(:test_strategy) { Flipflop::FeatureSet.current.test! }

      before do
        test_strategy.switch!(:entra_message, true)
      end
      after do
        test_strategy.switch!(:entra_message, false)
      end

      it "renders the homepage" do
        visit "/"
        expect(page).to have_text("PDC Describe now uses the Princeton-branded Microsoft sign-in page")
      end 
  end

  it "renders the homepage with admin menu for admin users" do
    sign_in super_admin_user
    visit "/"
    expect(page).to have_tag("nav", with: { id: "admin-actions" })
    expect(page).to have_tag("span", with: { id: "admin-badge" })
  end

  it "renders the homepage with admin menu for moderators" do
    sign_in research_data_moderator
    visit "/"
    expect(page).to have_tag("nav", with: { id: "admin-actions" })
    expect(page).to have_tag("span", with: { id: "moderator-badge" })
  end

  it "renders the homepage with out the admin menu for non-admin users" do
    sign_in user
    visit "/"
    expect(page).not_to have_tag("nav", with: { id: "admin-actions" })
  end
end
