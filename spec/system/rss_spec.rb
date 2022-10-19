# frozen_string_literal: true
require "rails_helper"

RSpec.describe "RSS feed of approved works, for harvesting and indexing", type: :system do
  let(:work1) { FactoryBot.create(:draft_work) }
  let(:work2) { FactoryBot.create(:draft_work) }
  let(:work3) { FactoryBot.create(:draft_work) }
  let(:admin) { FactoryBot.create(:super_admin_user) }
  let(:file_name) { "us_covid_2019.csv" }
  let(:uploaded_file) { fixture_file_upload(file_name, "text/csv") }
  let(:list_objects_response) do
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
      <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
          <Name>example-bucket</Name>
    <Prefix/>
    <KeyCount>1</KeyCount>
    <MaxKeys>1000</MaxKeys>
    <IsTruncated>false</IsTruncated>
    <Contents>
        <Key>#{file_name}</Key>
        <LastModified>2009-10-12T17:50:30.000Z</LastModified>
        <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
        <Size>434234</Size>
        <StorageClass>STANDARD</StorageClass>
    </Contents>
</ListBucketResult>
XML
  end

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))

    stub_request(:head, "https://example-bucket.s3.amazonaws.com/#{work1.s3_object_key}").to_return(status: 404)
    stub_request(:head, "https://example-bucket.s3.amazonaws.com/#{work2.s3_object_key}").to_return(status: 404)

    stub_request(:head, "https://example-bucket.s3.amazonaws.com/#{work1.s3_object_key}").to_return(status: 404)
    stub_request(:head, "https://example-bucket.s3.amazonaws.com/#{work2.s3_object_key}").to_return(status: 404)

    stub_request(:delete, "https://example-bucket.s3.amazonaws.com/#{work1.s3_object_key}").to_return(status: 200)
    stub_request(:delete, "https://example-bucket.s3.amazonaws.com/#{work2.s3_object_key}").to_return(status: 200)

    stub_request(:put, "https://example-bucket.s3.amazonaws.com/#{work1.s3_object_key}/us_covid_2019.csv").to_return(status: 200)
    stub_request(:put, "https://example-bucket.s3.amazonaws.com/#{work2.s3_object_key}/us_covid_2019.csv").to_return(status: 200)

    stub_request(:get, "https://example-bucket.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=#{work1.s3_object_key}/").to_return(
      status: 200,
      body: list_objects_response
    )
    stub_request(:get, "https://example-bucket.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=#{work2.s3_object_key}/").to_return(
      status: 200,
      body: list_objects_response
    )

    stub_request(:get, "https://example-bucket.s3.amazonaws.com/#{work1.s3_object_key}/us_covid_2019.csv").to_return(
      status: 200,
      body: {
        accept_ranges: "bytes",
        content_length: 3191,
        content_type: "image/jpeg",
        etag: "\"6805f2cfc46c0f04559748bb039d69ae\"",
        last_modified: Time.parse("Thu, 15 Dec 2016 01:19:41 GMT"),
        metadata: {
        },
        tag_count: 2,
        version_id: "null"
      }.to_json
    )
    stub_request(:get, "https://example-bucket.s3.amazonaws.com/#{work2.s3_object_key}/us_covid_2019.csv").to_return(
      status: 200,
      body: {
        accept_ranges: "bytes",
        content_length: 3191,
        content_type: "image/jpeg",
        etag: "\"6805f2cfc46c0f04559748bb039d69ae\"",
        last_modified: Time.parse("Thu, 15 Dec 2016 01:19:41 GMT"),
        metadata: {
        },
        tag_count: 2,
        version_id: "null"
      }.to_json
    )

    stub_request(:head, "https://example-bucket.s3.amazonaws.com/#{work1.s3_object_key}/us_covid_2019.csv").to_return(status: 200)
    stub_request(:head, "https://example-bucket.s3.amazonaws.com/#{work2.s3_object_key}/us_covid_2019.csv").to_return(status: 200)

    stub_request(:delete, "https://example-bucket.s3.amazonaws.com/#{work1.s3_object_key}/us_covid_2019.csv").to_return(status: 200)
    stub_request(:delete, "https://example-bucket.s3.amazonaws.com/#{work2.s3_object_key}/us_covid_2019.csv").to_return(status: 200)

    allow(work1).to receive(:publish_doi).and_return(true)
    allow(work2).to receive(:publish_doi).and_return(true)

    # Works 1 & 2 are approved, so they should show up in the RSS feed
    work1.pre_curation_uploads.attach(uploaded_file)
    work1.complete_submission!(admin)
    work1.approve!(admin)

    work2.pre_curation_uploads.attach(uploaded_file)
    work2.complete_submission!(admin)
    work2.approve!(admin)

    # Ensure work3 exists before running the tests, but leave it in draft state.
    # It should NOT appear in the RSS feed.
    work3
  end

  ##
  # Note that we do not require sign in for getting a list of approved works
  # or the JSON representation of a work
  it "provides a list of approved works, with links to their datacite records" do
    visit "/works.rss"
    doc = Nokogiri::XML(page.body)
    expect(doc.xpath("//item").size).to eq 2
    urls = doc.xpath("//item/url/text()").map(&:to_s)
    expect(urls.include?(work_url(work1, format: "json"))).to eq true
    expect(urls.include?(work_url(work2, format: "json"))).to eq true

    # Fetching the JSON for an approved work doesn't require authentication
    visit "/works/#{work1.id}.json"
    expect(JSON.parse(page.body)["titles"][0]["title"]).to eq work1.title

    # Fetching the JSON for a work that is not yet approved doesn't work
    visit "/works/#{work3.id}.json"
    expect(page).to have_content "You need to sign in"
  end
end
