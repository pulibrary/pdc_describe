# frozen_string_literal: true
require 'rails_helper'

describe '/about', type: :system do
    it 'renders the about page' do
      visit '/about'
      expect(page).to have_text("About Princeton's PDC Research Data Repository")
    end
  end