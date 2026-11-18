# frozen_string_literal: true

require "rails_helper"

describe "footer", type: :system do
  it "renders the correct footer links on homepage" do
    visit "/"
    expect(page).to have_selector(:link_or_button, "Accessibility")
    expect(page).to have_selector(:link_or_button, "Diversity & Non-Discrimination")
  end
end
