# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, js: true do
  let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
  let(:user) { work.created_by_user }

  before do
    stub_s3
    stub_ark
  end

  it "displays related identifiers" do
    sign_in user
    visit work_path(work)
    expect(page).to have_content "IsCitedBy"
    expect(page).to have_content "https://www.biorxiv.org/content/10.1101/545517v1"
  end

  context "when the description metadata contains URLs" do
    let(:description) { "This tests the link http://something.unusual.edu. It also has a summary." }
    let(:resource) { FactoryBot.build(:resource, doi: "10.34770/123-abc", description: description) }
    let(:work) { FactoryBot.create(:tokamak_work, resource: resource) }

    it "will render the URLs using HTML markup" do
      sign_in user
      visit work_path(work)
      expect(page).to have_link("http://something.unusual.edu")
    end
  end

  it "copies DOI to the clipboard" do
    sign_in user
    visit work_path(work)
    expect(page.html.include?('<button id="copy-doi"')).to be true

    # A test as follows would be preferrable
    #
    # ```
    #   expect(page).to have_content "COPY"
    #   click_on "COPY"
    #   expect(page).to have_content "COPIED"
    # ```
    #
    # but unfortunately this kind of test only works when we run RSpec like this:
    #
    #   RUN_IN_BROWSER=true bundle exec rspec spec/system/work_show_spec.rb
    #
  end
end
