# frozen_string_literal: true
require "rails_helper"

describe "/help", type: :system do
  it "renders the Help page" do
    visit "/help"
    expect(page).to have_text("Need help?")
    expect(page).to have_text("Who do I contact for assistance?")
  end
end
