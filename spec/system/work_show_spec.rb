# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, js: true do
  let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
  let(:user) { work.created_by_user }

  before do
    stub_s3
    page.driver.browser.manage.window.resize_to(2000, 2000)
  end

  it "displays related identifiers" do
    sign_in user
    visit work_path(work)
    expect(page).to have_content "IS_CITED_BY"
    expect(page).to have_content "https://www.biorxiv.org/content/10.1101/545517v1"
  end
end
