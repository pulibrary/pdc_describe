# frozen_string_literal: true
require "rails_helper"

describe "Application landing page", type: :system do
  it "has a footer with latest deploy information" do
    visit "/"
    expect(page).to have_content "last updated"
  end

  it "has a header with links to helpful info" do
    visit "/"
    expect(page).to have_link "About", href: /about/
    expect(page).to have_link "How to Submit", href: /how-to-submit/
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
