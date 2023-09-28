# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, js: true do
  let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
  let(:related_doi) { FactoryBot.build(:related_object) }
  let(:related_arxiv) { FactoryBot.build(:related_object_arxiv) }
  let(:related_isbn) { FactoryBot.build(:related_object_isbn) }
  let(:user) { work.created_by_user }

  before do
    stub_s3
    stub_ark
    work.resource.related_objects << related_doi
    work.resource.related_objects << related_arxiv
    work.resource.related_objects << related_isbn
    work.save
  end

  it "displays related objects" do
    sign_in user
    visit work_path(work)
    related_objects_displayed = page.find_all(:css, ".related_object")
    expect(related_objects_displayed.size).to eq 5
    expect(page).to have_link(href: "https://www.biorxiv.org/content/10.1101/545517v1")
    expect(page).to have_link(href: "https://doi.org/10.7554/eLife.52482")

    # These are the RelatedObjects created by FactoryBot
    expect(page).to have_link(related_doi.related_identifier, href: "https://doi.org/#{related_doi.related_identifier}")
    expect(page).to have_link(related_arxiv.related_identifier, href: "https://arxiv.org/abs/#{related_arxiv.related_identifier}")
    # ISBNs, and other identifiers that don't have an obvious place to link to, should not have links
    expect(page).not_to have_link(related_isbn.related_identifier)
    expect(page).to have_content related_isbn.related_identifier
  end

  context "when the description metadata contains URLs" do
    let(:description) { "This tests the link http://something.unusual.edu. It also has a summary." }
    let(:resource) { FactoryBot.build(:resource, doi: "10.34770/123-abc", description:) }
    let(:work) { FactoryBot.create(:tokamak_work, resource:) }

    it "will render the URLs using HTML markup" do
      sign_in user
      visit work_path(work)
      expect(page).to have_link("http://something.unusual.edu")
    end
  end

  it "uses datatables for easy navigation" do
    sign_in user
    visit work_path(work)

    expect(page).to have_css(".dataTables_length")
    expect(page).to have_css(".dataTables_filter")
    page.driver.go_back
    page.driver.go_forward
    expect(page).to have_css(".dataTables_length")
    expect(page).to have_css(".dataTables_filter")
    page.driver.go_back
    page.driver.go_forward
  end

  it "shows the PDC Discovery URL" do
    sign_in user
    visit work_path(work)
    expect(page).to have_link("https://datacommons.princeton.edu/discovery/catalog/doi-10-34770-r2dz-ys12")
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
