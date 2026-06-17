# frozen_string_literal: true
require "rails_helper"

describe "Application landing page", type: :system do
  it "has a link to PDC Discovery in the body of the page" do
    visit "/"
    expect(page).to have_link("Princeton Data Commons: Discovery", href: "https://datacommons.princeton.edu/discovery/")
  end
  it "has a footer with latest deploy information" do
    visit "/"
    expect(page).to have_content "last updated"
  end

  it "has a header with links to helpful info" do
    visit "/"
    expect(page).to have_link "Policies and Guidelines", href: "https://datacommons.princeton.edu/discovery/policies"
    expect(page).to have_link "Accessibility", href: "https://accessibility.princeton.edu/help"
  end

  context "an error in the footer" do
    before do
      allow(VersionFooter).to receive(:info).and_return({ error: "Error!!!" })
    end

    it "has a footer with error information" do
      visit "/"
      expect(page).to have_content "Error!!!"
    end
  end
end
