# frozen_string_literal: true
require "rails_helper"

RSpec.describe "RSS feed of approved works, for harvesting and indexing", type: :system, mock_ezid_api: true do
  let(:work1) { FactoryBot.create(:draft_work) }
  let(:work2) { FactoryBot.create(:draft_work) }
  let(:work3) { FactoryBot.create(:draft_work) }
  let(:admin) { FactoryBot.create(:super_admin_user) }
  let(:user) { FactoryBot.create(:princeton_submitter) }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    allow(work1).to receive(:publish_doi).and_return(true)
    allow(work2).to receive(:publish_doi).and_return(true)

    # Works 1 & 2 are approved, so they should show up in the RSS feed
    work1.complete_submission!(admin)
    work1.approve!(admin)

    work2.complete_submission!(admin)
    work2.approve!(admin)

    # Ensure work3 exists before running the tests, but leave it in draft state.
    # It should NOT appear in the RSS feed.
    work3
  end

  it "provides a list of approved works, with links to their datacite records" do
    sign_in user
    visit "/works.rss"
    doc = Nokogiri::XML(page.body)
    expect(doc.xpath("//item").size).to eq 2
    urls = doc.xpath("//item/url/text()").map(&:to_s)
    expect(urls.include?(datacite_work_url(work1))).to eq true
    expect(urls.include?(datacite_work_url(work2))).to eq true
  end
end
