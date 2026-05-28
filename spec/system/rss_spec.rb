# frozen_string_literal: true
require "rails_helper"

# approved draft withdrawn
RSpec.describe "RSS feed of approved works, for harvesting and indexing", type: :system do
  let(:approved_work) { FactoryBot.create(:draft_work) }
  let(:draft_work) { FactoryBot.create(:draft_work) }
  let(:withdrawn_work) { FactoryBot.create(:withdrawn_work) }
  let(:super_admin) { FactoryBot.create(:super_admin_user) }
  let(:s3_file1) { FactoryBot.build :s3_file, filename: "us_covid_2019.csv", work: approved_work }
  let(:s3_file2) { FactoryBot.build :s3_file, filename: "us_covid_2019.csv", work: approved_work }
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

    allow(approved_work).to receive(:publish).and_return(true)
    stub_s3(data: [FactoryBot.build(:s3_readme), s3_file1])

    # This work is approved
    approved_work.complete_submission!(super_admin)
    approved_work.approve!(super_admin)

    # Ensure draft_work exists before running the tests, but leave it in draft state.
    # It should appear in the RSS feed.
    draft_work

    # Ensure withdrawn_work exists before running the tests, so that it will appear in the /works.rss feed.
    withdrawn_work
  end

  ##
  # Note that we do not require sign in for getting a list of works
  # or the JSON representation of a work
  it "provides a list of works, with links to their datacite records" do
    visit "/works.rss"
    doc = Nokogiri::XML(page.body)
    expect(doc.xpath("//item").size).to eq 4
    urls = doc.xpath("//item/url/text()").map(&:to_s)
    expect(urls.include?(work_url(approved_work, format: "json"))).to eq true
  end

  context "when a work is not yet approved" do
    it "still appears in the RSS feed" do
      visit "/works.rss"
      doc = Nokogiri::XML(page.body)
      expect(doc.xpath("//item").size).to eq 4
    end

    it "can be harvested but there is only a DOI" do
      visit "/works/#{draft_work.id}.json"
      # make sure to test that only the DOI is included in the JSON document
      expect(JSON.parse(page.body)).to eq({ "resource" => { "doi" => draft_work.doi } })
      # make sure to test that the title is not in the JSON document
      expect(JSON.parse(page.body)["resource"]["titles"]).to be_nil
    end
  end

  context "when a work is approved" do
    it "is in the RSS feed" do
      visit "/works.rss"
      doc = Nokogiri::XML(page.body)
      expect(doc.xpath("//item").size).to eq 4
    end

    it "can be harvested" do
      visit "/works/#{approved_work.id}.json"
      expect(JSON.parse(page.body)["resource"]["titles"][0]["title"]).to eq approved_work.title
    end
  end

  context "When a work is withdrawn" do
    it "still appears in the RSS feed" do
      visit "/works.rss"
      doc = Nokogiri::XML(page.body)
      expect(doc.xpath("//item").size).to eq 4
    end

    it "can be harvested" do
      visit "/works/#{withdrawn_work.id}.json"
      expect(JSON.parse(page.body)).to eq({ "resource" => { "doi" => withdrawn_work.doi } })
      expect(JSON.parse(page.body)["resource"]["titles"]).to be_nil
    end
  end
end
