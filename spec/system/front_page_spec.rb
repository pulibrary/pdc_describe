# frozen_string_literal: true
require 'rails_helper'

describe 'Application landing page', type: :system do
    it "has a footer with latest deploy information" do
      visit '/'
      expect(page).to have_content "last updated"
    end
  
    it "has a header with links to helpful info" do
      visit '/'
      expect(page).to have_link "About", href: "/about"
    end
  end