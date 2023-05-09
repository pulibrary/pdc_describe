# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, js: true do
  let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
  let(:related_object) { FactoryBot.build(:related_object) }
  let(:user) { work.created_by_user }

  before do
    stub_s3
    stub_ark
    work.resource.related_objects << related_object
    work.save
  end

  it "displays related identifiers" do
    sign_in user
    visit work_path(work)
    related_objects_displayed = page.find_all(:css, ".related_object")
    expect(related_objects_displayed.size).to eq 3
    expect(page).to have_link(href: "https://www.biorxiv.org/content/10.1101/545517v1")
    expect(page).to have_link(href: "https://doi.org/10.7554/eLife.52482")

    # This one was added as a DOI without the https prefix. It came from the FactoryBot related_object.
    expect(page).to have_link(href: "https://doi.org/10.34770/220-abc")
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
