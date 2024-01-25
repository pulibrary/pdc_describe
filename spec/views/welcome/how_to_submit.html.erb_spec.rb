# frozen_string_literal: true
require "rails_helper"

describe "/how-to-submit", type: :system do
  it "renders the How to Submit page" do
    visit "/how-to-submit"
    expect(page).to have_text("How to Submit to Princeton's Research Data Repository")
    expect(page).to have_text("The review process typically takes 5-10 business days")
  end
end
