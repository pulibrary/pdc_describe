# frozen_string_literal: true

require "rails_helper"

RSpec.describe "License page" do
  describe "Displays for anyone" do
    it "shows any user the license page" do
      visit welcome_license_path
      expect(page).to have_content "Please take a moment to read the terms of this license"
    end
  end
end
